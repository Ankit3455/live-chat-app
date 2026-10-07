package com.example.flutter_webrtc_dating_app_v3

import android.util.Log
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import org.webrtc.JavaI420Buffer
import org.webrtc.VideoFrame
import java.nio.ByteBuffer
import java.util.ArrayDeque
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Edge-preserving skin smoothing for outgoing camera frames.
 *
 * Luma: each pixel is pulled towards a two-pass box blur unless it differs a
 * lot from it (eyes, brows, lips, hairline), then midtones are lifted a little.
 * Chroma: the same edge-preserving pull with a tighter threshold evens out
 * blotchy skin tone, plus a slight warm shift.
 *
 * Sits on the camera source, so the local preview and the encoder both get
 * the processed frames.
 *
 * Runs on the camera thread inside LocalVideoTrack's processor lock, so
 * [onFrame] is never concurrent with itself or with removeProcessor.
 * Only [level] is touched from other threads.
 */
class BeautyFrameProcessor : LocalVideoTrack.ExternalVideoFrameProcessing {

    @Volatile
    var level: Float = 0f
        set(value) {
            field = value.coerceIn(0f, 1f)
        }

    // Scratch buffers, reused while the frame size stays the same.
    private var frameW = 0
    private var frameH = 0
    private var scale = 1
    private var smallW = 0
    private var smallH = 0
    private var luma = ByteArray(0)
    private var small = IntArray(0)
    private var rowSums = IntArray(0)
    private var colSums = IntArray(0)
    private var outY = ByteArray(0)
    private var chroma = ByteArray(0)
    private var chromaBlur = IntArray(0)

    // delta[d + 255]: how far a pixel moves towards the blur when blur - y == d.
    private val delta = IntArray(511)
    private val chromaDelta = IntArray(511)
    private val tone = IntArray(256)
    private var warmU = 0
    private var warmV = 0
    private var lutLevel = -1f

    // The frame returned last time. LocalVideoTrack hands it to the sink but
    // never releases it, so we drop our reference on the next frame.
    private var pendingOutput: VideoFrame? = null

    private val pool = ArrayDeque<Planes>()

    private class Planes(
        val width: Int,
        val height: Int,
        val y: ByteBuffer,
        val u: ByteBuffer,
        val v: ByteBuffer,
    )

    override fun onFrame(frame: VideoFrame): VideoFrame {
        releasePending()
        val strength = level
        if (strength <= 0f) return frame

        val width = frame.buffer.width
        val height = frame.buffer.height
        if (width <= 0 || height <= 0 || width * height > MAX_PIXELS) return frame

        val i420 = try {
            frame.buffer.toI420()
        } catch (t: Throwable) {
            null
        } ?: return frame

        return try {
            val out = smooth(i420, width, height, strength, frame.rotation, frame.timestampNs)
            pendingOutput = out
            out
        } catch (t: Throwable) {
            Log.w(TAG, "beauty frame failed", t)
            frame
        } finally {
            i420.release()
        }
    }

    /** Drops our reference to the last output frame. Call after removeProcessor. */
    fun releasePending() {
        pendingOutput?.release()
        pendingOutput = null
    }

    private fun smooth(
        src: VideoFrame.I420Buffer,
        width: Int,
        height: Int,
        strength: Float,
        rotation: Int,
        timestampNs: Long,
    ): VideoFrame {
        ensureScratch(width, height)
        ensureLuts(strength)

        readPlane(src.dataY, src.strideY, width, height, luma)

        // Blur a half-size copy for HD frames: a quarter of the work, and the
        // blur is smooth enough that nearest upsampling is invisible. Two box
        // passes are close to a Gaussian, so no blocky halos.
        downscale(width, height)
        val sizeScale = min(width, height) / 360f
        val fullRadius = (3.5f + 6.5f * strength) * sizeScale
        val radius = (fullRadius * 0.6f / scale).roundToInt().coerceIn(1, 16)
        boxBlur(small, smallW, smallH, radius)
        boxBlur(small, smallW, smallH, radius)

        val sw = smallW
        val s = scale
        val lumaA = luma
        val blurA = small
        val outA = outY
        val toneA = tone
        val deltaA = delta
        var i = 0
        for (y in 0 until height) {
            val rowBase = min(y / s, smallH - 1) * sw
            for (x in 0 until width) {
                val yv = lumaA[i].toInt() and 0xFF
                val b = blurA[rowBase + min(x / s, sw - 1)]
                var o = toneA[yv + deltaA[b - yv + 255]]
                if (o < 0) o = 0 else if (o > 255) o = 255
                outA[i] = o.toByte()
                i++
            }
        }

        val planes = obtainPlanes(width, height)
        val cw = (width + 1) / 2
        val ch = (height + 1) / 2
        // Chroma is already half-size; a smaller radius covers the same area.
        val chromaRadius = (fullRadius * 0.3f).roundToInt().coerceIn(1, 8)

        planes.y.clear()
        planes.y.put(outY, 0, width * height)
        planes.y.rewind()

        readPlane(src.dataU, src.strideU, cw, ch, chroma)
        smoothChroma(cw * ch, cw, ch, chromaRadius, warmU)
        planes.u.clear()
        planes.u.put(chroma, 0, cw * ch)
        planes.u.rewind()

        readPlane(src.dataV, src.strideV, cw, ch, chroma)
        smoothChroma(cw * ch, cw, ch, chromaRadius, warmV)
        planes.v.clear()
        planes.v.put(chroma, 0, cw * ch)
        planes.v.rewind()

        val buffer = JavaI420Buffer.wrap(
            width, height,
            planes.y, width,
            planes.u, cw,
            planes.v, cw,
        ) { recycle(planes) }
        return VideoFrame(buffer, rotation, timestampNs)
    }

    /** Edge-preserving pull of [chroma] towards its blur, plus [shift], in place. */
    private fun smoothChroma(n: Int, w: Int, h: Int, r: Int, shift: Int) {
        val c = chroma
        val blur = chromaBlur
        for (i in 0 until n) blur[i] = c[i].toInt() and 0xFF
        boxBlur(blur, w, h, r)
        val deltaA = chromaDelta
        for (i in 0 until n) {
            val v = c[i].toInt() and 0xFF
            var o = v + deltaA[blur[i] - v + 255] + shift
            if (o < 0) o = 0 else if (o > 255) o = 255
            c[i] = o.toByte()
        }
    }

    private fun ensureScratch(width: Int, height: Int) {
        if (width == frameW && height == frameH) return
        frameW = width
        frameH = height
        scale = if (width * height > 640 * 480) 2 else 1
        smallW = (width + scale - 1) / scale
        smallH = (height + scale - 1) / scale
        val cw = (width + 1) / 2
        val ch = (height + 1) / 2
        luma = ByteArray(width * height)
        outY = ByteArray(width * height)
        chroma = ByteArray(cw * ch)
        chromaBlur = IntArray(cw * ch)
        small = IntArray(smallW * smallH)
        rowSums = IntArray(max(smallW * smallH, cw * ch))
        colSums = IntArray(max(smallW, cw))
        synchronized(pool) { pool.clear() }
    }

    private fun ensureLuts(strength: Float) {
        if (strength == lutLevel) return
        lutLevel = strength
        // Differences below `full` (skin texture, pores) are pulled almost all
        // the way to the blur; the pull fades out by `edge`, so larger ones
        // (eyes, lips, hairline) stay sharp.
        fillPull(delta, 0.6f + 0.35f * strength, 10f + 12f * strength, 26f + 24f * strength)
        // Skin blotches are a few chroma steps; lips and background colours
        // are well past the threshold.
        fillPull(chromaDelta, 0.5f + 0.4f * strength, 3f + 3f * strength, 10f + 6f * strength)

        // Midtone lift that leaves black and white where they are.
        val lift = 4f + 10f * strength
        for (v in 0..255) {
            tone[v] = v + (lift * 4f * v * (255 - v) / (255f * 255f)).roundToInt()
        }
        // Slightly warmer: a bit less blue (U), a bit more red (V).
        warmU = -(2.5f * strength).roundToInt()
        warmV = (2.5f * strength).roundToInt()
    }

    private fun fillPull(lut: IntArray, pull: Float, full: Float, edge: Float) {
        for (d in -255..255) {
            val a = abs(d).toFloat()
            val keep = when {
                a <= full -> 1f
                a >= edge -> 0f
                else -> 1f - (a - full) / (edge - full)
            }
            lut[d + 255] = (d * pull * keep).roundToInt()
        }
    }

    private fun readPlane(data: ByteBuffer, stride: Int, w: Int, h: Int, dst: ByteArray) {
        val src = data.duplicate()
        if (stride == w) {
            src.position(0)
            src.get(dst, 0, w * h)
            return
        }
        for (row in 0 until h) {
            src.position(row * stride)
            src.get(dst, row * w, w)
        }
    }

    private fun downscale(width: Int, height: Int) {
        if (scale == 1) {
            for (i in 0 until width * height) small[i] = luma[i].toInt() and 0xFF
            return
        }
        val sw = smallW
        for (sy in 0 until smallH) {
            val y0 = sy * 2
            val y1 = min(y0 + 1, height - 1)
            for (sx in 0 until sw) {
                val x0 = sx * 2
                val x1 = min(x0 + 1, width - 1)
                val sum = (luma[y0 * width + x0].toInt() and 0xFF) +
                    (luma[y0 * width + x1].toInt() and 0xFF) +
                    (luma[y1 * width + x0].toInt() and 0xFF) +
                    (luma[y1 * width + x1].toInt() and 0xFF)
                small[sy * sw + sx] = sum shr 2
            }
        }
    }

    /** Separable running-sum box blur of [src] (w x h), in place. Edges are clamped. */
    private fun boxBlur(src: IntArray, w: Int, h: Int, r: Int) {
        val rows = rowSums

        for (y in 0 until h) {
            val base = y * w
            var sum = 0
            for (i in -r..r) sum += src[base + i.coerceIn(0, w - 1)]
            for (x in 0 until w) {
                rows[base + x] = sum
                sum += src[base + min(x + r + 1, w - 1)] - src[base + max(x - r, 0)]
            }
        }

        val cols = colSums
        for (x in 0 until w) {
            var sum = 0
            for (j in -r..r) sum += rows[j.coerceIn(0, h - 1) * w + x]
            cols[x] = sum
        }
        val side = 2 * r + 1
        val area = side * side
        // 20-bit reciprocal: exact enough to not darken, and sum * inv fits an Int.
        val inv = ((1 shl 20) + area / 2) / area
        for (y in 0 until h) {
            val base = y * w
            val addRow = min(y + r + 1, h - 1) * w
            val subRow = max(y - r, 0) * w
            for (x in 0 until w) {
                val sum = cols[x]
                src[base + x] = min((sum * inv + (1 shl 19)) ushr 20, 255)
                cols[x] = sum + rows[addRow + x] - rows[subRow + x]
            }
        }
    }

    private fun obtainPlanes(width: Int, height: Int): Planes {
        synchronized(pool) {
            while (true) {
                val p = pool.pollFirst() ?: break
                if (p.width == width && p.height == height) return p
            }
        }
        val cw = (width + 1) / 2
        val ch = (height + 1) / 2
        val ySize = width * height
        val cSize = cw * ch
        val all = ByteBuffer.allocateDirect(ySize + 2 * cSize)
        return Planes(
            width,
            height,
            slice(all, 0, ySize),
            slice(all, ySize, cSize),
            slice(all, ySize + cSize, cSize),
        )
    }

    // Called by WebRTC (any thread) once nothing references the buffer.
    // Wrong-sized entries are dropped by obtainPlanes.
    private fun recycle(planes: Planes) {
        synchronized(pool) {
            if (pool.size < POOL_SIZE) pool.addLast(planes)
        }
    }

    private fun slice(all: ByteBuffer, offset: Int, length: Int): ByteBuffer {
        val dup = all.duplicate()
        dup.position(offset)
        dup.limit(offset + length)
        return dup.slice()
    }

    companion object {
        private const val TAG = "BeautyFrameProcessor"
        private const val MAX_PIXELS = 1280 * 720
        private const val POOL_SIZE = 4
    }
}
