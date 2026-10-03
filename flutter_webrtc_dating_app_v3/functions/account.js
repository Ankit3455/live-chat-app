// Account deletion (DEST-011). Exported from index.js.
//
// Decision: delete profile, photos, auth account and push identity. Messages
// already sent stay in the other person's chat; the conversation marks the
// sender as deleted so clients show "Deleted user". senderId is kept (an
// opaque id that no longer resolves to an account) because clients and rules
// compare it with the current uid.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();

const config = require('./config');
const { STORAGE_HOST, CLOUDINARY_HOST, storagePath } = require('./media_utils');
const { oneSignalRestApiKey } = config;

const RECENT_AUTH_SECONDS = 5 * 60;
const GAMES = ['carrom', 'ludo'];
const STORAGE_PREFIXES = (uid) => [`voices/${uid}/`, `profile_photos/${uid}/`, `avatars/${uid}_avatar_`];

const db = () => admin.firestore();

function log(uid, step, err) {
  console.error(`deleteAccount ${uid}: ${step} failed: ${err && err.message ? err.message : err}`);
}

// Collects media URLs from the profile so they can be removed.
function mediaUrls(profile) {
  const urls = new Set();
  const visit = (value, depth) => {
    if (depth > 3 || value == null) return;
    if (typeof value === 'string') {
      if (value.includes(STORAGE_HOST) || value.includes(CLOUDINARY_HOST)) urls.add(value);
    } else if (Array.isArray(value)) {
      value.forEach((v) => visit(v, depth + 1));
    } else if (typeof value === 'object') {
      Object.values(value).forEach((v) => visit(v, depth + 1));
    }
  };
  visit(profile, 0);
  return [...urls];
}

async function deleteStorage(uid, urls) {
  const bucket = admin.storage().bucket();
  for (const prefix of STORAGE_PREFIXES(uid)) {
    await bucket.deleteFiles({ prefix, force: true });
  }
  // Legacy flat paths (e.g. profile_photos/<ts>.jpg) are only known from the profile.
  const paths = urls.map(storagePath).filter(Boolean);
  await Promise.all(paths.map((p) => bucket.file(p).delete({ ignoreNotFound: true })));
}

// Cloudinary needs the API secret (owner action O-7). Queue the URLs for the
// media cleanup function instead of failing the deletion.
async function queueCloudinaryCleanup(uid, urls) {
  const cloudinary = urls.filter((u) => u.includes(CLOUDINARY_HOST));
  if (cloudinary.length === 0) return;
  await db().collection('media_cleanup').add({
    reason: 'account_deleted',
    uid,
    urls: cloudinary.slice(0, 200),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// Removes both sides of every block involving uid.
async function deleteBlocks(uid) {
  const userRef = db().collection('users').doc(uid);
  const [blocked, blockedBy] = await Promise.all([
    userRef.collection('blocked').get(),
    userRef.collection('blockedBy').get(),
  ]);
  const writer = db().bulkWriter();
  blocked.docs.forEach((d) => writer.delete(db().doc(`users/${d.id}/blockedBy/${uid}`)));
  blockedBy.docs.forEach((d) => writer.delete(db().doc(`users/${d.id}/blocked/${uid}`)));
  await writer.close();
}

async function anonymiseConversations(uid) {
  const snap = await db().collection('conversations').where('participants', 'array-contains', uid).get();
  const FieldValue = admin.firestore.FieldValue;
  for (const doc of snap.docs) {
    const conv = doc.data();
    const deletedUsers = Array.isArray(conv.deletedUsers) ? conv.deletedUsers : [];
    const others = (conv.participants || []).filter((p) => p !== uid);
    const everyoneGone = others.every((p) => deletedUsers.includes(p));
    if (everyoneGone) {
      // Nobody is left to read it.
      await db().recursiveDelete(doc.ref);
      continue;
    }
    // participants stays as-is (immutable, ordered; it backs the deterministic id).
    await doc.ref.update({
      deletedUsers: FieldValue.arrayUnion(uid),
      [`participantData.${uid}`]: { deleted: true, unreadCount: 0 },
      [`statePerUser.${uid}`]: FieldValue.delete(),
      [`typingAt.${uid}`]: FieldValue.delete(),
    });
  }
}

async function deleteGameData(uid) {
  const writer = db().bulkWriter();
  writer.delete(db().doc(`ludo_queue/${uid}`));
  writer.delete(db().doc(`carrom_queue/${uid}`));
  for (const game of GAMES) {
    writer.delete(db().doc(`leaderboards/${game}/allTime/${uid}`));
    for (const period of ['daily', 'weekly']) {
      const keys = await db().collection(`leaderboards/${game}/${period}`).listDocuments();
      keys.forEach((k) => writer.delete(k.collection('users').doc(uid)));
    }
  }
  await writer.close();
  await db().recursiveDelete(db().doc(`user_game_stats/${uid}`));
}

async function deleteRealtime(uid) {
  const rtdb = admin.database();
  await Promise.all([
    rtdb.ref(`presence/${uid}`).remove(),
    rtdb.ref(`incoming_calls/${uid}`).remove(),
  ]);
  // Rooms this user started have ids "<callerUid>_<uuid>". Rooms where the
  // user was the callee are removed by the scheduled room cleanup.
  const rooms = await rtdb
    .ref('rooms')
    .orderByKey()
    .startAt(`${uid}_`)
    .endAt(`${uid}_\uf8ff`)
    .get();
  if (rooms.exists()) {
    const updates = {};
    rooms.forEach((child) => {
      updates[child.key] = null;
    });
    await rtdb.ref('rooms').update(updates);
  }
}

async function deleteOneSignalUser(uid) {
  const response = await fetch(
    `https://api.onesignal.com/apps/${config.oneSignalAppId.value()}/users/by/external_id/${encodeURIComponent(uid)}`,
    { method: 'DELETE', headers: { Authorization: `Basic ${oneSignalRestApiKey.value()}` } },
  );
  if (!response.ok && response.status !== 404) {
    throw new Error(`OneSignal ${response.status}: ${await response.text()}`);
  }
}

// Runs a cleanup step; failures are logged and reported, not fatal.
async function step(uid, name, fn, failed) {
  try {
    await fn();
  } catch (err) {
    log(uid, name, err);
    failed.push(name);
  }
}

exports.deleteAccount = onCall(
  config.callable({ secrets: [oneSignalRestApiKey], timeoutSeconds: 300, memory: '512MiB' }),
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in required');

    const authTime = Number(request.auth.token.auth_time || 0);
    if (Date.now() / 1000 - authTime > RECENT_AUTH_SECONDS) {
      throw new HttpsError('failed-precondition', 'requires-recent-login');
    }

    const userRef = db().collection('users').doc(uid);
    const profile = (await userRef.get()).data() || {};
    const urls = mediaUrls(profile);
    const failed = [];

    // Order: shared data first, then the profile, then the Auth user last so
    // a failed run can be retried while still signed in.
    await step(uid, 'conversations', () => anonymiseConversations(uid), failed);
    await step(uid, 'blocks', () => deleteBlocks(uid), failed);
    await step(uid, 'games', () => deleteGameData(uid), failed);
    await step(uid, 'realtime', () => deleteRealtime(uid), failed);
    await step(uid, 'storage', () => deleteStorage(uid, urls), failed);
    await step(uid, 'cloudinary', () => queueCloudinaryCleanup(uid, urls), failed);
    await step(uid, 'onesignal', () => deleteOneSignalUser(uid), failed);

    try {
      await Promise.all([
        db().recursiveDelete(userRef),
        db().recursiveDelete(db().doc(`public_profiles/${uid}`)),
      ]);
    } catch (err) {
      log(uid, 'profile', err);
      throw new HttpsError('internal', 'Could not delete profile data');
    }

    try {
      await admin.auth().deleteUser(uid);
    } catch (err) {
      if (err.code !== 'auth/user-not-found') {
        log(uid, 'auth', err);
        throw new HttpsError('internal', 'Could not delete sign-in');
      }
    }

    if (failed.length) console.warn(`deleteAccount ${uid}: finished with failed steps: ${failed.join(', ')}`);
    return { ok: true, incomplete: failed };
  },
);
