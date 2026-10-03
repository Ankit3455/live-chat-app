package com.example.flutter_webrtc_dating_app_v3

import android.annotation.TargetApi
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val AUDIO_CHANNEL = "audio_manager_channel"
    private var audioManager: AudioManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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