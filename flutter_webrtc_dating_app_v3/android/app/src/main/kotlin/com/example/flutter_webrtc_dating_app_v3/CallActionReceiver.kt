package com.example.flutter_webrtc_dating_app_v3

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ServerValue
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Decline button of the ringing notification. Stops the ringing at once and
 * ends the call so the caller stops ringing too: through Flutter when it is
 * running, otherwise with a native RTDB write. If that fails the decline
 * stays pending and Flutter sends it on the next start (consumePendingDeclines).
 */
class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != CallNotifier.ACTION_DECLINE) return
        val call = CallNotifier.IncomingCall.fromIntent(intent) ?: return
        val app = context.applicationContext
        CallNotifier.finish(app, call.callId)
        CallNotifier.addPendingDecline(app, call.callId)

        val pending = goAsync()
        val declineNatively = {
            CallDecliner.decline(app, call.callId) { ok ->
                if (ok) CallNotifier.removePendingDecline(app, call.callId)
                pending.finish()
            }
        }
        val sentToFlutter = MainActivity.sendCallAction(call.toMap("decline")) { handled ->
            if (handled) pending.finish() else declineNatively()
        }
        if (!sentToFlutter) declineNatively()
    }
}

/** Same writes as CallService.rejectCall: room ended/declined, inbox entry removed. */
private object CallDecliner {
    private const val TIMEOUT_MS = 8_000L

    fun decline(context: Context, callId: String, done: (Boolean) -> Unit) {
        val finished = AtomicBoolean(false)
        val finish = { ok: Boolean -> if (finished.compareAndSet(false, true)) done(ok) }
        Handler(Looper.getMainLooper()).postDelayed({ finish(false) }, TIMEOUT_MS)

        try {
            if (FirebaseApp.getApps(context).isEmpty()) FirebaseApp.initializeApp(context)
            val uid = FirebaseAuth.getInstance().currentUser?.uid
            if (uid == null) {
                finish(false)
                return
            }
            val db = database()
            val room = db.getReference("rooms").child(callId)
            val inbox = db.getReference("incoming_calls").child(uid).child(callId)
            val removeInbox = {
                inbox.removeValue().addOnCompleteListener { finish(it.isSuccessful) }
            }

            room.child("state").get().addOnCompleteListener { read ->
                if (!read.isSuccessful) {
                    finish(false)
                    return@addOnCompleteListener
                }
                val state = read.result?.value as? String
                if (state == null || state == "ended") {
                    removeInbox()
                    return@addOnCompleteListener
                }
                val updates = mapOf<String, Any>(
                    "state" to "ended",
                    "endReason" to "declined",
                    "endedBy" to uid,
                    "endedAt" to ServerValue.TIMESTAMP,
                )
                room.updateChildren(updates).addOnCompleteListener { write ->
                    if (write.isSuccessful) removeInbox() else finish(false)
                }
            }
        } catch (e: Exception) {
            android.util.Log.w("CallActionReceiver", "native decline failed: $e")
            finish(false)
        }
    }

    // Mirrors main.dart (persistence on, 10 MB) in case this process later
    // hosts Flutter; those settings only apply before the first use.
    private fun database(): FirebaseDatabase {
        val db = FirebaseDatabase.getInstance()
        try {
            db.setPersistenceEnabled(true)
            db.setPersistenceCacheSizeBytes(10L * 1024 * 1024)
        } catch (ignored: Exception) {
            // Already in use in this process.
        }
        return db
    }
}
