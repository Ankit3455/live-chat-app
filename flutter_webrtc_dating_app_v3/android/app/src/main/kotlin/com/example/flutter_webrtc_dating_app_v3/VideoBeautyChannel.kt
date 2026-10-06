package com.example.flutter_webrtc_dating_app_v3

import android.util.Log
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * 'video_beauty' channel (lib/services/call/beauty_filter.dart). Attaches one
 * [BeautyFrameProcessor] per local video track, so set/clear always add and
 * remove the same instance. Main thread only.
 */
object VideoBeautyChannel {
    private const val CHANNEL = "video_beauty"
    private const val TAG = "VideoBeauty"

    private class Attached(val track: LocalVideoTrack, val processor: BeautyFrameProcessor)

    private val attached = HashMap<String, Attached>()

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                val trackId = call.argument<String>("trackId")
                when (call.method) {
                    "setBeauty" -> {
                        val level = call.argument<Number>("level")?.toFloat() ?: 0f
                        result.success(trackId != null && setBeauty(trackId, level))
                    }
                    "clear" -> {
                        if (trackId != null) clear(trackId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.w(TAG, "${call.method} failed", e)
                result.error("beauty_failed", e.message, null)
            }
        }
    }

    private fun setBeauty(trackId: String, level: Float): Boolean {
        if (level <= 0f) {
            clear(trackId)
            return true
        }
        attached[trackId]?.let {
            it.processor.level = level
            return true
        }
        val track = FlutterWebRTCPlugin.sharedSingleton?.getLocalTrack(trackId) as? LocalVideoTrack
            ?: return false
        val processor = BeautyFrameProcessor().also { it.level = level }
        track.addProcessor(processor)
        attached[trackId] = Attached(track, processor)
        return true
    }

    private fun clear(trackId: String) {
        val entry = attached.remove(trackId) ?: return
        // Blocks until an in-flight frame finishes, so releasePending is safe after.
        entry.track.removeProcessor(entry.processor)
        entry.processor.releasePending()
    }
}
