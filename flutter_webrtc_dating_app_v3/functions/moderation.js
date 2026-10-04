// Block and report support (DEST-003). Exported from index.js:
//   const moderation = require('./moderation');
//   exports.onReportCreated = moderation.onReportCreated;
//   exports.onBlockWritten = moderation.onBlockWritten;
// Push functions should skip delivery when moderation.isBlockedBetween(a, b).
//
// Data model (written by the app's SafetyService):
//   users/{uid}/blocked/{other}    owner-written
//   users/{other}/blockedBy/{uid}  mirror, written by the blocker
//   reports/{id}                   {reporterId, reportedUserId, reason, ...}
//   moderation/{uid}               server-only summary for console review

const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();

const db = () => admin.firestore();

async function isBlockedBetween(a, b) {
  if (!a || !b || a === b) return false;
  const [ab, ba] = await Promise.all([
    db().doc(`users/${a}/blocked/${b}`).get(),
    db().doc(`users/${b}/blocked/${a}`).get(),
  ]);
  return ab.exists || ba.exists;
}

// Keeps the blockedBy mirror in step with blocked (covers partial or legacy
// client writes) and drops ringing calls between the two users.
const onBlockWritten = onDocumentWritten('users/{uid}/blocked/{otherId}', async (event) => {
  const { uid, otherId } = event.params;
  if (uid === otherId) return;
  const mirror = db().doc(`users/${otherId}/blockedBy/${uid}`);
  const blockedRef = db().doc(`users/${uid}/blocked/${otherId}`);

  // Events can arrive out of order, so mirror the current state, not the event.
  const stillBlocked = await db().runTransaction(async (tx) => {
    const current = await tx.get(blockedRef);
    if (!current.exists) {
      tx.delete(mirror);
      return false;
    }
    tx.set(
      mirror,
      { blockedAt: current.get('blockedAt') || admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
    return true;
  });
  const created = event.data && !event.data.before.exists && event.data.after.exists;
  if (!stillBlocked || !created) return;

  const rtdb = admin.database();
  await Promise.all(
    [
      [uid, otherId],
      [otherId, uid],
    ].map(async ([callee, caller]) => {
      const snap = await rtdb.ref(`incoming_calls/${callee}`).orderByChild('callerId').equalTo(caller).get();
      if (!snap.exists()) return;
      const updates = {};
      snap.forEach((child) => {
        updates[child.key] = null;
      });
      await rtdb.ref(`incoming_calls/${callee}`).update(updates);
    }),
  );
});

// Stamps the report and keeps a per-user summary the owner can sort by in
// the console. Each reporter counts once per reported user.
const onReportCreated = onDocumentCreated('reports/{reportId}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const report = snap.data() || {};
  const reporterId = String(report.reporterId || report.reporterUid || '');
  const reportedId = String(report.reportedUserId || report.reportedUid || '');
  if (!reporterId || !reportedId || reporterId === reportedId || reportedId.includes('/')) {
    await snap.ref.set({ status: 'invalid' }, { merge: true });
    return;
  }

  const FieldValue = admin.firestore.FieldValue;
  const summaryRef = db().doc(`moderation/${reportedId}`);
  const reporterRef = summaryRef.collection('reporters').doc(reporterId);
  const reason = String(report.reason || 'Other').slice(0, 100);

  await db().runTransaction(async (tx) => {
    const seen = await tx.get(reporterRef);
    tx.set(
      summaryRef,
      {
        reportCount: FieldValue.increment(1),
        ...(seen.exists ? {} : { uniqueReporters: FieldValue.increment(1) }),
        lastReportAt: FieldValue.serverTimestamp(),
        lastReason: reason,
      },
      { merge: true },
    );
    tx.set(reporterRef, { lastReportAt: FieldValue.serverTimestamp(), lastReportId: snap.id }, { merge: true });
    tx.set(
      snap.ref,
      { status: 'open', receivedAt: FieldValue.serverTimestamp(), repeatFromReporter: seen.exists },
      { merge: true },
    );
  });
});

module.exports = { isBlockedBetween, onBlockWritten, onReportCreated };
