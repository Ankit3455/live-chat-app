// OneSignal pushes for chat messages and calls (DEST-051/065/066/003/012/025/008).
//
// Chat: the onChatMessageCreated trigger sends one push per message. The
// sendChatPush callable is kept for existing clients and shares the same
// one-time receipt, so a message is pushed once whichever runs first.
// Calls: sendCallPush verifies the room and inbox entry, consent and blocks.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

const config = require('./config');
const {
  db,
  requireUid,
  requireString,
  rateLimit,
  claimOnce,
  releaseClaim,
  isBlockedBetween,
  findConversation,
  callAllowed,
  stateFor,
  isMuted,
  isDeletedUser,
} = require('./common');
const { pushBody } = require('./conversation_rules');

const CHANNEL_CHAT = 'onesignal_chat_channel';
const CHANNEL_NEW_CHAT = 'onesignal_new_chat_channel'; // silent, low importance
const CHANNEL_AUDIO_CALL = 'onesignal_audio_call_channel';
const CHANNEL_VIDEO_CALL = 'onesignal_video_call_channel';
const IOS_CALL_SOUND = 'incoming_call.caf';

const CALL_PUSH_MAX_AGE_MS = 90 * 1000;
const CALL_PUSH_PER_MINUTE = 10;
const CHAT_PUSH_PER_MINUTE = 60;

async function sendToOneSignal(payload) {
  const response = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      Authorization: `Basic ${config.oneSignalRestApiKey.value()}`,
    },
    body: JSON.stringify({ app_id: config.oneSignalAppId.value(), target_channel: 'push', ...payload }),
  });
  if (!response.ok) {
    console.error(`OneSignal error ${response.status}: ${await response.text()}`);
    throw new Error(`OneSignal ${response.status}`);
  }
}

async function displayName(uid) {
  const snap = await db().doc(`users/${uid}`).get();
  const data = snap.data() || {};
  return String(data.username || data.name || 'Someone').slice(0, 60);
}

// Receiver's push switches from users/{uid}.notificationSettings.
async function pushSettings(uid) {
  const snap = await db().doc(`users/${uid}`).get();
  if (!snap.exists) return { exists: false, push: false, messages: false };
  const s = snap.get('notificationSettings') || {};
  return { exists: true, push: s.pushEnabled !== false, messages: s.messageNotifications !== false };
}

function chatChannel(conv, receiverId) {
  return stateFor(conv, receiverId) === 'active' ? CHANNEL_CHAT : CHANNEL_NEW_CHAT;
}

// Common receiver checks for anything shown in a chat. Returns a skip reason or null.
async function chatSkipReason(conv, senderId, receiverId) {
  if (isDeletedUser(conv, receiverId)) return 'receiver-deleted';
  if (isMuted(conv, receiverId)) return 'muted';
  const [blocked, settings] = await Promise.all([
    isBlockedBetween(senderId, receiverId),
    pushSettings(receiverId),
  ]);
  if (blocked) return 'blocked';
  if (!settings.exists) return 'receiver-missing';
  if (!settings.push || !settings.messages) return 'disabled';
  return null;
}

async function sendMissedCallPush({ callId, callerId, calleeId, callType, conversationId, conv }) {
  const isVideo = callType === 'video';
  const callerName = await displayName(callerId);
  await sendToOneSignal({
    include_aliases: { external_id: [calleeId] },
    headings: { en: callerName },
    contents: { en: `Missed ${isVideo ? 'video' : 'audio'} call` },
    existing_android_channel_id: conv ? chatChannel(conv, calleeId) : CHANNEL_CHAT,
    priority: 10,
    ...(conversationId ? { collapse_id: `chat_${conversationId}`.slice(0, 64), thread_id: conversationId } : {}),
    data: {
      type: 'missed_call',
      callId,
      callerId,
      callType: isVideo ? 'video' : 'audio',
      receiverId: calleeId,
      conversationId: conversationId || null,
    },
  });
}

// Sends the push for one message, at most once. Returns a short status.
async function deliverChatPush(conversationId, messageId, msg, conv) {
  if (!msg || !conv) return 'missing';
  if (msg.isDeleted === true) return 'deleted';
  const senderId = msg.senderId;
  const receiverId = msg.receiverId;
  const participants = Array.isArray(conv.participants) ? conv.participants : [];
  if (!senderId || !receiverId || senderId === receiverId
      || !participants.includes(senderId) || !participants.includes(receiverId)) {
    return 'invalid';
  }

  const type = String(msg.type || 'text');
  const meta = msg.metadata && typeof msg.metadata === 'object' ? msg.metadata : {};
  if (type === 'call' && meta.callStatus === 'declined') return 'declined';

  const skip = await chatSkipReason(conv, senderId, receiverId);
  if (skip) return skip;

  // Missed calls share a key with the scheduled sweep (cleanup.js).
  const key = type === 'call' && typeof meta.callId === 'string' && !meta.callId.includes('/')
    ? `missed_${meta.callId}`
    : `chat_${conversationId}_${messageId}`;
  if (!(await claimOnce(key, { conversationId, messageId }))) return 'duplicate';

  try {
    if (type === 'call') {
      await sendMissedCallPush({
        callId: meta.callId || null,
        callerId: senderId,
        calleeId: receiverId,
        callType: meta.callType,
        conversationId,
        conv,
      });
      return 'sent';
    }

    const silent = stateFor(conv, receiverId) !== 'active';
    await sendToOneSignal({
      include_aliases: { external_id: [receiverId] },
      headings: { en: await displayName(senderId) },
      contents: { en: pushBody(msg, config.ONESIGNAL_IDENTITY_VERIFIED) },
      existing_android_channel_id: chatChannel(conv, receiverId),
      priority: silent ? 5 : 10,
      ...(silent ? { ios_interruption_level: 'passive' } : {}),
      collapse_id: `chat_${conversationId}`.slice(0, 64),
      thread_id: conversationId,
      data: { type: 'new_message', conversationId, messageId, senderId, receiverId, messageType: type },
    });
    return 'sent';
  } catch (err) {
    await releaseClaim(key);
    throw err;
  }
}

exports.onChatMessageCreated = onDocumentCreated(
  { document: 'conversations/{conversationId}/messages/{messageId}', secrets: [config.oneSignalRestApiKey] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const { conversationId, messageId } = event.params;
    const convSnap = await db().doc(`conversations/${conversationId}`).get();
    const status = await deliverChatPush(conversationId, messageId, snap.data(), convSnap.data());
    if (status !== 'sent' && status !== 'duplicate') console.log(`chat push ${conversationId}/${messageId}: ${status}`);
  },
);

// Kept for existing clients; the trigger above also covers messages whose
// sender never calls this (media, call events, offline sends).
exports.sendChatPush = onCall(
  config.callable({ secrets: [config.oneSignalRestApiKey] }),
  async (request) => {
    const uid = requireUid(request);
    const conversationId = requireString(request.data, 'conversationId');
    const messageId = requireString(request.data, 'messageId');

    const convRef = db().collection('conversations').doc(conversationId);
    const [convSnap, msgSnap] = await Promise.all([
      convRef.get(),
      convRef.collection('messages').doc(messageId).get(),
    ]);
    const conv = convSnap.data();
    const msg = msgSnap.data();
    if (!conv || !msg || msg.senderId !== uid) {
      throw new HttpsError('permission-denied', 'Not your message');
    }
    await rateLimit(uid, 'chat_push', CHAT_PUSH_PER_MINUTE, 60);

    try {
      const status = await deliverChatPush(conversationId, messageId, msg, conv);
      if (status === 'invalid') throw new HttpsError('permission-denied', 'Not a participant');
      return { ok: true, status };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError('internal', 'Push send failed');
    }
  },
);

// Ends a call the server refused so the caller stops ringing.
async function refuseCall(receiverId, callId, hasRoom) {
  const rtdb = admin.database();
  const updates = { [`incoming_calls/${receiverId}/${callId}`]: null };
  if (hasRoom) {
    updates[`rooms/${callId}/state`] = 'ended';
    updates[`rooms/${callId}/endReason`] = 'failed';
    updates[`rooms/${callId}/endedAt`] = admin.database.ServerValue.TIMESTAMP;
  }
  await rtdb.ref().update(updates);
}

// Caller must have written rooms/{callId} and the ringing inbox entry, the
// call type must be enabled by both users, and neither may block the other.
exports.sendCallPush = onCall(
  config.callable({ secrets: [config.oneSignalRestApiKey] }),
  async (request) => {
    const uid = requireUid(request);
    const receiverId = requireString(request.data, 'receiverId');
    const callId = requireString(request.data, 'callId');
    if (receiverId === uid || !callId.startsWith(`${uid}_`)) {
      throw new HttpsError('permission-denied', 'No ringing call from you');
    }
    await rateLimit(uid, 'call_push', CALL_PUSH_PER_MINUTE, 60);

    const rtdb = admin.database();
    const [inboxSnap, roomSnap] = await Promise.all([
      rtdb.ref(`incoming_calls/${receiverId}/${callId}`).get(),
      rtdb.ref(`rooms/${callId}`).get(),
    ]);
    const call = inboxSnap.val();
    if (!call || call.callerId !== uid || call.status !== 'ringing') {
      throw new HttpsError('permission-denied', 'No ringing call from you');
    }
    const room = roomSnap.val();
    // Legacy builds (callId "<caller>_<callee>_<ms>") may not write a room.
    const legacyId = callId.startsWith(`${uid}_${receiverId}_`);
    if (room) {
      if (room.callerId !== uid || room.calleeId !== receiverId
          || !['ringing', 'active'].includes(room.state)) {
        throw new HttpsError('permission-denied', 'No ringing call from you');
      }
    } else if (!legacyId) {
      throw new HttpsError('permission-denied', 'No ringing call from you');
    }
    if (typeof call.timestamp === 'number' && Date.now() - call.timestamp > CALL_PUSH_MAX_AGE_MS) {
      throw new HttpsError('failed-precondition', 'Call is no longer ringing');
    }

    const isVideo = call.callType === 'video';
    const [blocked, convSnap, settings] = await Promise.all([
      isBlockedBetween(uid, receiverId),
      findConversation(uid, receiverId),
      pushSettings(receiverId),
    ]);
    const conv = convSnap ? convSnap.data() : null;
    if (blocked || !conv || isDeletedUser(conv, receiverId)
        || !callAllowed(conv, uid, receiverId, isVideo ? 'video' : 'audio')) {
      await refuseCall(receiverId, callId, !!room);
      throw new HttpsError('permission-denied', blocked ? 'blocked' : 'call-not-allowed');
    }
    if (!settings.push) return { ok: true, status: 'disabled' };

    const key = `call_${callId}`;
    if (!(await claimOnce(key, { callerId: uid, receiverId }))) return { ok: true, status: 'duplicate' };

    const callerName = await displayName(uid);
    try {
      await sendToOneSignal({
        include_aliases: { external_id: [receiverId] },
        headings: { en: `Incoming ${isVideo ? 'Video' : 'Voice'} Call` },
        contents: { en: `${callerName} is calling...` },
        existing_android_channel_id: isVideo ? CHANNEL_VIDEO_CALL : CHANNEL_AUDIO_CALL,
        priority: 10,
        ttl: 60,
        ios_interruption_level: 'time_sensitive',
        ios_sound: IOS_CALL_SOUND,
        data: {
          type: 'call',
          callId,
          callerId: uid,
          callerName,
          callerAvatar: typeof call.callerAvatar === 'string' ? call.callerAvatar : null,
          callType: isVideo ? 'video' : 'audio',
          receiverId,
          conversationId: convSnap.id,
        },
      });
    } catch (err) {
      await releaseClaim(key);
      throw new HttpsError('internal', 'Push send failed');
    }
    return { ok: true, status: 'sent' };
  },
);

exports.sendMissedCallPush = sendMissedCallPush;
exports.chatSkipReason = chatSkipReason;
