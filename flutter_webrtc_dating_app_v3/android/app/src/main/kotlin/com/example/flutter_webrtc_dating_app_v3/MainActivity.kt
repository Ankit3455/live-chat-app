package com.example.flutter_webrtc_dating_app_v3

import android.annotation.TargetApi
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val AUDIO_CHANNEL = "audio_manager_channel"
    private var audioManager: AudioManager? = null

    private var callChannel: MethodChannel? = null
    // CALL_SHOW / CALL_ACCEPT that launched the activity, until Flutter asks for it.
    private var initialCallAction: Map<String, Any?>? = null

    companion object {
        private const val CALL_CHANNEL = "call_intent"

        /** Read by CallNotificationExtension (OneSignal background thread). */
        @Volatile
        var isInForeground = false
            private set

        // Main thread only.
        private var liveCallChannel: MethodChannel? = null

        /**
         * Hands [args] to Flutter's onCallAction if an engine is running.
         * [onResult] gets whether Flutter handled it. Main thread only.
         */
        fun sendCallAction(args: Map<String, Any?>, onResult: (Boolean) -> Unit): Boolean {
            val channel = liveCallChannel ?: return false
            channel.invokeMethod("onCallAction", args, object : MethodChannel.Result {
                override fun success(result: Any?) = onResult(result == true)
                override fun error(code: String, message: String?, details: Any?) = onResult(false)
                override fun notImplemented() = onResult(false)
            })
            return true
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Lock-screen flags must be set before the window is shown. Skipped when
        // the activity is recreated, or reopened from Recents with the old intent.
        val fromHistory = ((intent?.flags ?: 0) and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        val launchCall = if (savedInstanceState == null && !fromHistory) callActionFrom(intent) else null
        if (launchCall != null) showOverLockScreen(true)
        super.onCreate(savedInstanceState)
        createNotificationChannels()
        CallNotifier.ensureChannel(this)
        if (launchCall != null) {
            prepareForCall(launchCall)
            initialCallAction = launchCall
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = callActionFrom(intent) ?: return
        prepareForCall(action)
        val channel = callChannel
        if (channel == null) {
            initialCallAction = action
            return
        }
        // Flutter may not have registered its handler yet (still starting).
        channel.invokeMethod("onCallAction", action, object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(code: String, message: String?, details: Any?) {}
            override fun notImplemented() {
                initialCallAction = action
            }
        })
    }

    override fun onResume() {
        super.onResume()
        isInForeground = true
    }

    override fun onPause() {
        isInForeground = false
        super.onPause()
    }

    override fun onDestroy() {
        if (liveCallChannel === callChannel) liveCallChannel = null
        callChannel = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialCallAction" -> {
                    result.success(initialCallAction)
                    initialCallAction = null
                }
                "canUseFullScreenIntent" -> result.success(CallNotifier.canUseFullScreenIntent(this))
                "openFullScreenIntentSettings" -> result.success(openFullScreenIntentSettings())
                "cancelCallNotification" -> {
                    val callId = call.argument<String>("callId")
                    if (!callId.isNullOrEmpty()) CallNotifier.finish(this, callId)
                    result.success(null)
                }
                "releaseLockScreen" -> {
                    showOverLockScreen(false)
                    result.success(null)
                }
                "consumePendingDeclines" -> result.success(CallNotifier.consumePendingDeclines(this))
                else -> result.notImplemented()
            }
        }
        callChannel = channel
        liveCallChannel = channel

        VideoBeautyChannel.register(flutterEngine.dartExecutor.binaryMessenger)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setCallAudioMode" -> {
                        val inCall = call.argument<Boolean>("inCall") ?: false
                        setCallAudioMode(inCall)
                        result.success(null)
                    }
                    "setSpeakerphone" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setSpeakerphone(enabled)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Channel IDs must match existing_android_channel_id sent by functions/index.js.
    // A channel's sound cannot change after creation, so new sounds need a new ID.
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val notificationAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()
        val ringtoneAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .build()

        val chatChannel = NotificationChannel(
            "onesignal_chat_channel",
            "Chat Messages",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Messages in your active chats"
            setSound(rawSound("notification_sound"), notificationAttributes)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 300, 200, 300)
        }

        // First messages from someone you have not replied to yet: no sound, no heads-up.
        val newChatChannel = NotificationChannel(
            "onesignal_new_chat_channel",
            "New Chat Requests",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Messages from people you have not replied to yet"
            setSound(null, null)
            enableVibration(false)
        }

        val audioCallChannel = callChannel(
            "onesignal_audio_call_channel",
            "Voice Calls",
            "Incoming voice calls",
            ringtoneAttributes
        )
        val videoCallChannel = callChannel(
            "onesignal_video_call_channel",
            "Video Calls",
            "Incoming video calls",
            ringtoneAttributes
        )

        getSystemService(NotificationManager::class.java).createNotificationChannels(
            listOf(chatChannel, newChatChannel, audioCallChannel, videoCallChannel)
        )
    }

    @TargetApi(Build.VERSION_CODES.O)
    private fun callChannel(
        id: String,
        name: String,
        channelDescription: String,
        attributes: AudioAttributes
    ) = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
        description = channelDescription
        setSound(rawSound("incoming_call"), attributes)
        enableVibration(true)
        vibrationPattern = longArrayOf(0, 800, 400, 800)
        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
    }

    // ---------- incoming call intents (CallNotifier) ----------

    private fun callActionFrom(intent: Intent?): Map<String, Any?>? {
        val action = when (intent?.action) {
            CallNotifier.ACTION_SHOW -> "show"
            CallNotifier.ACTION_ACCEPT -> "accept"
            else -> return null
        }
        return CallNotifier.IncomingCall.fromIntent(intent)?.toMap(action)
    }

    // Shows the call over the lock screen. On Accept the ringing stops at once;
    // for Show it keeps ringing until Flutter's incoming-call screen takes over.
    private fun prepareForCall(action: Map<String, Any?>) {
        showOverLockScreen(true)
        if (action["action"] != "accept") return
        (action["callId"] as? String)?.let { CallNotifier.finish(this, it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(KeyguardManager::class.java)?.requestDismissKeyguard(this, null)
        }
    }

    // Undone from Flutter (releaseLockScreen) when the call UI closes.
    private fun showOverLockScreen(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    private fun openFullScreenIntentSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return false
        val uri = Uri.parse("package:$packageName")
        return try {
            startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, uri))
            true
        } catch (e: Exception) {
            try {
                startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                )
                true
            } catch (e2: Exception) {
                false
            }
        }
    }

    private fun rawSound(name: String): Uri = Uri.parse(
        ContentResolver.SCHEME_ANDROID_RESOURCE + "://" + packageName + "/raw/" + name
    )

    private fun setCallAudioMode(inCall: Boolean) {
        audioManager?.let { am ->
            if (inCall) {
                am.mode = AudioManager.MODE_IN_COMMUNICATION
                am.isSpeakerphoneOn = true

                @Suppress("DEPRECATION")
                am.requestAudioFocus(
                    null,
                    AudioManager.STREAM_VOICE_CALL,
                    AudioManager.AUDIOFOCUS_GAIN
                )

                android.util.Log.d("AudioManager", "Set to MODE_IN_COMMUNICATION + speaker on")
            } else {
                am.mode = AudioManager.MODE_NORMAL
                am.isSpeakerphoneOn = false

                @Suppress("DEPRECATION")
                am.abandonAudioFocus(null)

                android.util.Log.d("AudioManager", "Set to MODE_NORMAL")
            }
        }
    }

    private fun setSpeakerphone(enabled: Boolean) {
        audioManager?.isSpeakerphoneOn = enabled
        android.util.Log.d("AudioManager", "Speakerphone: ${if (enabled) "on" else "off"}")
    }
}