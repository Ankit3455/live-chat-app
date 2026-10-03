// Helpers shared by the function modules.

const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();

const { isBlockedBetween } = require('./moderation');
const { participantData, callAllowed, stateFor, isMuted, isDeletedUser } = require('./conversation_rules');

const db = () => admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const RECEIPT_TTL_MS = 3 * 24 * 60 * 60 * 1000;

function requireUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required');
  return uid;
}

function requireString(data, field, maxLength = 200) {
  const value = data && data[field];
  if (typeof value !== 'string' || value.length === 0 || value.length > maxLength || value.includes('/')) {
    throw new HttpsError('invalid-argument', `${field} is required`);
  }
  return value;
}

// Fixed-window limiter in rate_limits/{uid}_{name} (server-only collection).
async function rateLimit(uid, name, max, windowSeconds) {
  const ref = db().doc(`rate_limits/${uid}_${name}`);
  const now = Date.now();
  const allowed = await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() || {};
    const start = typeof data.windowStart === 'number' ? data.windowStart : 0;
    const inWindow = now - start < windowSeconds * 1000;
    const count = inWindow ? Number(data.count || 0) : 0;
    if (count >= max) return false;
    tx.set(ref, {
      windowStart: inWindow ? start : now,
      count: count + 1,
      expiresAt: Timestamp.fromMillis(now + Math.max(windowSeconds * 1000, 3600 * 1000)),
    });
    return true;
  });
  if (!allowed) throw new HttpsError('resource-exhausted', 'Too many requests, try again shortly');
}

// Claims a one-time key in push_receipts (server-only). Returns false if the
// key was already claimed, which makes push sends idempotent across retries,
// replays and the callable/trigger pair.
async function claimOnce(key, extra = {}) {
  try {
    await db().doc(`push_receipts/${key}`).create({
      ...extra,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + RECEIPT_TTL_MS),
    });
    return true;
  } catch (err) {
    if (err && (err.code === 6 || err.code === 'already-exists')) return false;
    throw err;
  }
}

async function releaseClaim(key) {
  try {
    await db().doc(`push_receipts/${key}`).delete();
  } catch (_) {
    // A stale receipt only suppresses one retry.
  }
}

// The 1:1 conversation between two users: deterministic id first, then the
// legacy participants == [sorted] query. Returns a snapshot or null.
async function findConversation(uidA, uidB) {
  const sorted = [uidA, uidB].sort();
  const direct = await db().doc(`conversations/${sorted[0]}_${sorted[1]}`).get();
  if (direct.exists) return direct;
  const q = await db()
    .collection('conversations')
    .where('participants', '==', sorted)
    .limit(1)
    .get();
  return q.empty ? null : q.docs[0];
}

module.exports = {
  db,
  FieldValue,
  Timestamp,
  requireUid,
  requireString,
  rateLimit,
  claimOnce,
  releaseClaim,
  isBlockedBetween,
  findConversation,
  participantData,
  callAllowed,
  stateFor,
  isMuted,
  isDeletedUser,
};
