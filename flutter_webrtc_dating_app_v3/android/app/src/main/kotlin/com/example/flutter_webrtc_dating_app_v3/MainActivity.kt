package com.example.flutter_webrtc_dating_app_v3

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

    // ✅ App start hote hi channel banao
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
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

    // ✅ Custom Sound Notification Channel
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val channelId = "onesignal_chat_channel"
            val channelName = "Chat Messages"

            // Custom sound URI
            val soundUri = Uri.parse(
                ContentResolver.SCHEME_ANDROID_RESOURCE + "://" +
                        packageName + "/raw/notification_sound"
            )

            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Chat message notifications"
                setSound(soundUri, audioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)

            android.util.Log.d("NotificationChannel", "✅ Custom channel created: $channelId")
        }
    }

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

                android.util.Log.d("AudioManager", "✅ Set to MODE_IN_COMMUNICATION + Speaker ON")
            } else {
                am.mode = AudioManager.MODE_NORMAL
                am.isSpeakerphoneOn = false

                @Suppress("DEPRECATION")
                am.abandonAudioFocus(null)

                android.util.Log.d("AudioManager", "✅ Set to MODE_NORMAL")
            }
        }
    }

    private fun setSpeakerphone(enabled: Boolean) {
        audioManager?.isSpeakerphoneOn = enabled
        android.util.Log.d("AudioManager", "🔊 Speakerphone: ${if (enabled) "ON" else "OFF"}")
    }
}