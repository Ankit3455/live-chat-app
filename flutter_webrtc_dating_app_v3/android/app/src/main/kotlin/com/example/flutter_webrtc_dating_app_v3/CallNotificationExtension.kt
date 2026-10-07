package com.example.flutter_webrtc_dating_app_v3

import androidx.annotation.Keep
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension

/**
 * Runs for every OneSignal push, also when the app is closed (registered in
 * AndroidManifest.xml as com.onesignal.NotificationServiceExtension).
 * Call pushes are drawn by [CallNotifier] instead of OneSignal's default
 * notification; everything else is left to OneSignal. Runs on a background
 * thread; if it throws, OneSignal shows its default notification instead.
 */
@Keep
class CallNotificationExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val data = event.notification.additionalData ?: return
        when (data.optString("type")) {
            "call" -> {
                // Restored after a reboot/update: the call is long over. In the
                // foreground it rings too, unless Flutter's incoming-call screen
                // already took the call (it marks the call handled), so a missed
                // in-app listener can never swallow a call.
                val result = when {
                    event.restoring -> CallNotifier.Result.SKIPPED
                    else -> CallNotifier.IncomingCall.fromJson(data)
                        ?.let { CallNotifier.showRinging(event.context, it) }
                        ?: CallNotifier.Result.FAILED
                }
                // true = discard: no 30 s wait for display(), never restored later.
                // On FAILED OneSignal shows its default notification as a fallback.
                if (result != CallNotifier.Result.FAILED) event.preventDefault(true)
            }
            "call_cancel" -> {
                event.preventDefault(true)
                val callId = data.optString("callId")
                if (callId.isNotEmpty()) CallNotifier.finish(event.context, callId)
            }
        }
    }
}
