package com.example.flutter_webrtc_dating_app_v3

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import org.json.JSONObject

/**
 * Native ringing notification for an incoming call, shown while the Flutter
 * side is not running (app in background or closed). Taps open MainActivity
 * with a CALL_* action; Decline goes to [CallActionReceiver].
 */
object CallNotifier {
    // A channel's sound cannot change after creation, so a new sound needs a new id.
    // Must match CHANNEL_CALL_RING in cloudflare/push-worker/src/index.js.
    const val CHANNEL_ID = "incoming_call_ring_v1"

    const val ACTION_SHOW = "com.example.flutter_webrtc_dating_app_v3.CALL_SHOW"
    const val ACTION_ACCEPT = "com.example.flutter_webrtc_dating_app_v3.CALL_ACCEPT"
    const val ACTION_DECLINE = "com.example.flutter_webrtc_dating_app_v3.CALL_DECLINE"

    private const val TAG = "incoming_call"
    private const val RING_TIMEOUT_MS = 60_000L
    private const val STALE_AFTER_MS = 60_000L
    private const val MIN_RING_MS = 5_000L
    private const val REMEMBER_MS = 10 * 60_000L

    private const val PREFS = "call_notifier"
    private const val KEY_HANDLED = "handled_calls"
    private const val KEY_PENDING_DECLINES = "pending_declines"

    private val VIBRATION = longArrayOf(0, 800, 400, 800)

    /** Push `data` / intent extras for one call. */
    data class IncomingCall(
        val callId: String,
        val callerId: String,
        val callerName: String,
        val isVideo: Boolean,
        val receiverId: String?,
        val conversationId: String?,
        val startedAt: Long?,
    ) {
        fun toBundle() = Bundle().apply {
            putString("callId", callId)
            putString("callerId", callerId)
            putString("callerName", callerName)
            putString("callType", if (isVideo) "video" else "audio")
            putString("receiverId", receiverId)
            putString("conversationId", conversationId)
            if (startedAt != null) putLong("timestamp", startedAt)
        }

        fun toMap(action: String): Map<String, Any?> = mapOf(
            "action" to action,
            "callId" to callId,
            "callerId" to callerId,
            "callerName" to callerName,
            "callType" to if (isVideo) "video" else "audio",
            "receiverId" to receiverId,
            "conversationId" to conversationId,
        )

        companion object {
            fun fromJson(data: JSONObject): IncomingCall? {
                fun str(key: String) = data.optString(key, "").takeIf { it.isNotEmpty() && it != "null" }
                val callId = str("callId") ?: return null
                val callerId = str("callerId") ?: return null
                val ts = data.optLong("timestamp", 0L)
                return IncomingCall(
                    callId = callId,
                    callerId = callerId,
                    callerName = str("callerName") ?: "Someone",
                    isVideo = str("callType") == "video",
                    receiverId = str("receiverId"),
                    conversationId = str("conversationId"),
                    startedAt = ts.takeIf { it > 0L },
                )
            }

            fun fromIntent(intent: Intent?): IncomingCall? {
                val extras = intent?.extras ?: return null
                val callId = extras.getString("callId")?.takeIf { it.isNotEmpty() } ?: return null
                val callerId = extras.getString("callerId")?.takeIf { it.isNotEmpty() } ?: return null
                val ts = extras.getLong("timestamp", 0L)
                return IncomingCall(
                    callId = callId,
                    callerId = callerId,
                    callerName = extras.getString("callerName") ?: "Someone",
                    isVideo = extras.getString("callType") == "video",
                    receiverId = extras.getString("receiverId"),
                    conversationId = extras.getString("conversationId"),
                    startedAt = ts.takeIf { it > 0L },
                )
            }
        }
    }

    enum class Result { SHOWN, SKIPPED, FAILED }

    /** Rings unless the call is stale or already answered/declined. */
    fun showRinging(context: Context, call: IncomingCall): Result {
        val age = call.startedAt?.let { System.currentTimeMillis() - it } ?: 0L
        if (age > STALE_AFTER_MS) return Result.SKIPPED
        if (isHandled(context, call.callId)) return Result.SKIPPED
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return Result.SKIPPED
        }
        return try {
            post(context, call, age)
            Result.SHOWN
        } catch (e: Exception) {
            android.util.Log.w("CallNotifier", "ringing notification failed: $e")
            Result.FAILED
        }
    }

    @SuppressLint("MissingPermission") // checked in showRinging
    private fun post(context: Context, call: IncomingCall, age: Long) {
        ensureChannel(context)

        val base = requestCodeBase(call.callId)
        val show = activityIntent(context, ACTION_SHOW, call, base)
        val fullScreen = activityIntent(context, ACTION_SHOW, call, base + 1)
        val accept = activityIntent(context, ACTION_ACCEPT, call, base + 2)
        val decline = PendingIntent.getBroadcast(
            context,
            base + 3,
            Intent(context, CallActionReceiver::class.java).apply {
                action = ACTION_DECLINE
                putExtras(call.toBundle())
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val caller = Person.Builder()
            .setName(call.callerName)
            .setImportant(true)
            .build()
        val kind = if (call.isVideo) "video" else "voice"

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_call)
            .setContentTitle(call.callerName)
            .setContentText("Incoming $kind call on Destined")
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setTimeoutAfter(maxOf(RING_TIMEOUT_MS - age, MIN_RING_MS))
            // Channel settings win on Android 8+; these cover Android 7.
            .setSound(rawSound(context), AudioManager.STREAM_RING)
            .setVibrate(VIBRATION)
            .setContentIntent(show)
            .setFullScreenIntent(fullScreen, true)
        // Android 12+ only accepts CallStyle with a usable full-screen intent
        // (or a foreground service), so fall back to plain actions without it.
        if (canUseFullScreenIntent(context)) {
            builder.setStyle(
                NotificationCompat.CallStyle.forIncomingCall(caller, decline, accept)
                    .setIsVideo(call.isVideo)
            )
        } else {
            builder.addPerson(caller)
                .addAction(0, "Decline", decline)
                .addAction(0, "Accept", accept)
        }
        val notification = builder.build()
        // Repeat the ringtone until answered, declined or timed out.
        notification.flags = notification.flags or Notification.FLAG_INSISTENT
        NotificationManagerCompat.from(context).notify(TAG, notificationId(call.callId), notification)
    }

    /** False on Android 14+ until the user allows full-screen notifications. */
    fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = context.getSystemService(NotificationManager::class.java) ?: return true
        return manager.canUseFullScreenIntent()
    }

    fun cancel(context: Context, callId: String) {
        NotificationManagerCompat.from(context).cancel(TAG, notificationId(callId))
    }

    /** Stops the ringing and makes sure a late push for [callId] stays silent. */
    fun finish(context: Context, callId: String) {
        markHandled(context, callId)
        cancel(context, callId)
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val attributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .build()
        val channel = NotificationChannel(CHANNEL_ID, "Incoming Calls", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Rings for incoming voice and video calls"
            setSound(rawSound(context), attributes)
            enableVibration(true)
            vibrationPattern = VIBRATION
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(false)
        }
        manager.createNotificationChannel(channel)
    }

    // ---------- answered / declined ids ----------

    fun markHandled(context: Context, callId: String) = addEntry(context, KEY_HANDLED, callId)

    private fun isHandled(context: Context, callId: String) =
        entries(context, KEY_HANDLED).containsKey(callId)

    /** Declines the Flutter side still has to send (see consumePendingDeclines). */
    fun addPendingDecline(context: Context, callId: String) = addEntry(context, KEY_PENDING_DECLINES, callId)

    fun removePendingDecline(context: Context, callId: String) {
        val kept = entries(context, KEY_PENDING_DECLINES).filterKeys { it != callId }
        save(context, KEY_PENDING_DECLINES, kept)
    }

    fun consumePendingDeclines(context: Context): List<String> {
        val ids = entries(context, KEY_PENDING_DECLINES).keys.toList()
        save(context, KEY_PENDING_DECLINES, emptyMap())
        return ids
    }

    @Synchronized
    private fun addEntry(context: Context, key: String, callId: String) {
        val map = entries(context, key).toMutableMap()
        map[callId] = System.currentTimeMillis()
        save(context, key, map)
    }

    /** callId -> time added, without entries older than [REMEMBER_MS]. */
    private fun entries(context: Context, key: String): Map<String, Long> {
        val now = System.currentTimeMillis()
        val raw = prefs(context).getStringSet(key, null) ?: return emptyMap()
        val out = HashMap<String, Long>()
        for (entry in raw) {
            val split = entry.lastIndexOf('|')
            if (split <= 0) continue
            val at = entry.substring(split + 1).toLongOrNull() ?: continue
            if (now - at in 0L..REMEMBER_MS) out[entry.substring(0, split)] = at
        }
        return out
    }

    private fun save(context: Context, key: String, map: Map<String, Long>) {
        val set = map.entries.mapTo(HashSet()) { "${it.key}|${it.value}" }
        prefs(context).edit().putStringSet(key, set).apply()
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ---------- helpers ----------

    private fun notificationId(callId: String) = "call:$callId".hashCode()

    // Four PendingIntents per call; the base keeps different calls apart.
    private fun requestCodeBase(callId: String) = (callId.hashCode() and 0x0FFFFFFF) shl 2

    private fun activityIntent(context: Context, action: String, call: IncomingCall, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtras(call.toBundle())
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun rawSound(context: Context): Uri = Uri.parse(
        ContentResolver.SCHEME_ANDROID_RESOURCE + "://" + context.packageName + "/raw/incoming_call"
    )
}
