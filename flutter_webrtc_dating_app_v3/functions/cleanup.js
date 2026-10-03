// Scheduled cleanup (DEST-022, DEST-049, DEST-087 backup for the TTL policy).
//
// Every 5 minutes:
//  - incoming_calls entries older than 2 minutes are removed. A call that was
//    still 'ringing' (caller app died) and never answered gets one missed-call
//    push (same receipt key as the chat trigger, so never twice).
//  - rooms: ended rooms after 3 minutes, unanswered ringing rooms after
//    5 minutes, accepted rooms after 12 hours, anything else after 2 hours.
//  - expired matchmaking queue docs, push receipts and rate-limit windows.
//
// Add ".indexOn": ["state", "createdAt"] on rooms in database.rules.json so
// the room queries run on the server.

const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

const config = require('./config');
const { db, Timestamp, claimOnce, isBlockedBetween, findConversation, callAllowed } = require('./common');
const { sendMissedCallPush, chatSkipReason } = require('./push');

const MINUTE = 60 * 1000;
const INBOX_MAX_AGE = 2 * MINUTE;
// Longer than INBOX_MAX_AGE so the missed-call check still finds the room.
const ENDED_ROOM_GRACE = 3 * MINUTE;
const RINGING_ROOM_MAX_AGE = 5 * MINUTE;
const ROOM_MAX_AGE = 2 * 60 * MINUTE;
const ACCEPTED_ROOM_MAX_AGE = 12 * 60 * MINUTE;
const QUEUE_GRACE = 10 * MINUTE;
const LEGACY_QUEUE_MAX_AGE = 2 * 60 * MINUTE;
const BATCH = 400;

function millis(value) {
  if (typeof value === 'number') return value;
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  return null;
}

// Legacy room ids were "<caller>_<callee>_<ms>".
function legacyRoomMillis(id) {
  const m = /_(\d{12,14})$/.exec(id);
  return m ? Number(m[1]) : null;
}

async function maybeMissedCallPush(calleeId, callId, entry, room) {
  const callerId = entry.callerId;
  if (typeof callerId !== 'string' || !callerId || callerId === calleeId) return;
  // Answered calls have an answer; missing rooms were cleaned up after a normal end.
  if (!room || room.answer || room.callerId !== callerId || room.calleeId !== calleeId) return;

  const callType = entry.callType === 'video' ? 'video' : 'audio';
  const [blocked, convSnap] = await Promise.all([
    isBlockedBetween(callerId, calleeId),
    findConversation(callerId, calleeId),
  ]);
  const conv = convSnap ? convSnap.data() : null;
  if (blocked || !conv || !callAllowed(conv, callerId, calleeId, callType)) return;
  if (await chatSkipReason(conv, callerId, calleeId)) return;
  if (!(await claimOnce(`missed_${callId}`, { callerId, calleeId, source: 'sweep' }))) return;

  await sendMissedCallPush({ callId, callerId, calleeId, callType, conversationId: convSnap.id, conv });
}

async function sweepIncomingCalls(now) {
  const rtdb = admin.database();
  const snap = await rtdb.ref('incoming_calls').get();
  if (!snap.exists()) return 0;

  const updates = {};
  const missed = [];
  snap.forEach((user) => {
    user.forEach((call) => {
      const entry = call.val() || {};
      const ts = millis(entry.timestamp);
      if (ts !== null && now - ts < INBOX_MAX_AGE) return;
      updates[`${user.key}/${call.key}`] = null;
      if (entry.status === 'ringing') missed.push([user.key, call.key, entry]);
    });
  });

  for (const [calleeId, callId, entry] of missed) {
    try {
      const room = (await rtdb.ref(`rooms/${callId}`).get()).val();
      await maybeMissedCallPush(calleeId, callId, entry, room);
    } catch (err) {
      console.error(`missed call push ${callId} failed: ${err.message || err}`);
    }
  }

  const count = Object.keys(updates).length;
  if (count) await rtdb.ref('incoming_calls').update(updates);
  return count;
}

function roomExpired(id, room, now) {
  const state = room.state;
  const createdAt = millis(room.createdAt) ?? legacyRoomMillis(id);
  if (state === 'ended') {
    // onDisconnect ends a room without endedAt.
    const endedAt = millis(room.endedAt) ?? createdAt;
    return endedAt === null || now - endedAt > ENDED_ROOM_GRACE;
  }
  if (createdAt === null) return state !== 'accepted';
  const age = now - createdAt;
  if (state === 'ringing' && !room.answer) return age > RINGING_ROOM_MAX_AGE;
  if (state === 'accepted') return age > ACCEPTED_ROOM_MAX_AGE;
  return age > ROOM_MAX_AGE;
}

async function sweepRooms(now) {
  const ref = admin.database().ref('rooms');
  const [ended, old] = await Promise.all([
    ref.orderByChild('state').equalTo('ended').get(),
    // Rooms without createdAt sort first, so legacy rooms are included.
    ref.orderByChild('createdAt').endAt(now - RINGING_ROOM_MAX_AGE).get(),
  ]);
  const updates = {};
  for (const snap of [ended, old]) {
    snap.forEach((room) => {
      if (roomExpired(room.key, room.val() || {}, now)) updates[room.key] = null;
    });
  }
  const count = Object.keys(updates).length;
  if (count) await ref.update(updates);
  return count;
}

async function deleteDocs(docs) {
  if (!docs.length) return 0;
  const writer = db().bulkWriter();
  docs.forEach((d) => writer.delete(d.ref));
  await writer.close();
  return docs.length;
}

async function sweepQueues(now) {
  let count = 0;
  for (const name of ['ludo_queue', 'carrom_queue']) {
    const col = db().collection(name);
    const expired = await col.where('expiresAt', '<', Timestamp.fromMillis(now - QUEUE_GRACE)).limit(BATCH).get();
    count += await deleteDocs(expired.docs);
    // Entries from builds that did not write expiresAt.
    const legacy = await col.where('createdAt', '<', Timestamp.fromMillis(now - LEGACY_QUEUE_MAX_AGE)).limit(BATCH).get();
    count += await deleteDocs(legacy.docs.filter((d) => d.get('expiresAt') == null));
  }
  return count;
}

async function sweepExpiring(now) {
  let count = 0;
  for (const name of ['push_receipts', 'rate_limits']) {
    const snap = await db().collection(name).where('expiresAt', '<', Timestamp.fromMillis(now)).limit(BATCH).get();
    count += await deleteDocs(snap.docs);
  }
  return count;
}

exports.scheduledCleanup = onSchedule(
  { schedule: 'every 5 minutes', secrets: [config.oneSignalRestApiKey], timeoutSeconds: 300 },
  async () => {
    const now = Date.now();
    const results = {};
    // Inbox before rooms: the missed-call check reads the room.
    for (const [name, fn] of [
      ['incoming_calls', sweepIncomingCalls],
      ['rooms', sweepRooms],
      ['queues', sweepQueues],
      ['expiring', sweepExpiring],
    ]) {
      try {
        results[name] = await fn(now);
      } catch (err) {
        console.error(`cleanup ${name} failed: ${err.message || err}`);
        results[name] = 'failed';
      }
    }
    console.log(`cleanup: ${JSON.stringify(results)}`);
  },
);
