// OneSignal push sending. The REST API key is a Secret Manager secret:
//   firebase functions:secrets:set ONESIGNAL_REST_API_KEY

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

admin.initializeApp();

const ONESIGNAL_APP_ID = 'f4489084-4880-4e7f-aa6d-a3b0cfb8beb4';
const oneSignalRestApiKey = defineSecret('ONESIGNAL_REST_API_KEY');

function requireUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required');
  return uid;
}

function requireString(data, field) {
  const value = data && data[field];
  if (typeof value !== 'string' || value.length === 0 || value.includes('/')) {
    throw new HttpsError('invalid-argument', `${field} is required`);
  }
  return value;
}

async function senderName(uid) {
  const snap = await admin.firestore().collection('users').doc(uid).get();
  const data = snap.data() || {};
  return String(data.username || data.name || 'Someone');
}

async function sendToOneSignal(payload) {
  const response = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      Authorization: `Basic ${oneSignalRestApiKey.value()}`,
    },
    body: JSON.stringify({ app_id: ONESIGNAL_APP_ID, target_channel: 'push', ...payload }),
  });
  if (!response.ok) {
    console.error(`OneSignal error ${response.status}: ${await response.text()}`);
    throw new HttpsError('internal', 'Push send failed');
  }
}

// Sender must have written the message, and the receiver must be the other participant.
exports.sendChatPush = onCall({ secrets: [oneSignalRestApiKey] }, async (request) => {
  const uid = requireUid(request);
  const conversationId = requireString(request.data, 'conversationId');
  const messageId = requireString(request.data, 'messageId');

  const convRef = admin.firestore().collection('conversations').doc(conversationId);
  const [convSnap, msgSnap] = await Promise.all([
    convRef.get(),
    convRef.collection('messages').doc(messageId).get(),
  ]);
  const conv = convSnap.data();
  const msg = msgSnap.data();
  if (!conv || !msg || msg.senderId !== uid) {
    throw new HttpsError('permission-denied', 'Not your message');
  }
  const participants = Array.isArray(conv.participants) ? conv.participants : [];
  const receiverId = msg.receiverId;
  if (!participants.includes(uid) || !participants.includes(receiverId) || receiverId === uid) {
    throw new HttpsError('permission-denied', 'Not a participant');
  }

  const text = String(msg.message || '');
  const trimmed = text.length > 120 ? `${text.substring(0, 117)}...` : text;

  await sendToOneSignal({
    include_aliases: { external_id: [receiverId] },
    headings: { en: await senderName(uid) },
    contents: { en: trimmed },
    existing_android_channel_id: 'onesignal_chat_channel',
    priority: 10,
    data: { type: 'new_message', conversationId, senderId: uid, receiverId },
  });
  return { ok: true };
});

// Caller must have created the ringing entry in the receiver's incoming_calls inbox.
exports.sendCallPush = onCall({ secrets: [oneSignalRestApiKey] }, async (request) => {
  const uid = requireUid(request);
  const receiverId = requireString(request.data, 'receiverId');
  const callId = requireString(request.data, 'callId');

  const snap = await admin.database().ref(`incoming_calls/${receiverId}/${callId}`).get();
  const call = snap.val();
  if (!call || call.callerId !== uid || call.status !== 'ringing') {
    throw new HttpsError('permission-denied', 'No ringing call from you');
  }

  const isVideo = call.callType === 'video';
  const callerName = await senderName(uid);

  await sendToOneSignal({
    include_aliases: { external_id: [receiverId] },
    headings: { en: `Incoming ${isVideo ? 'Video' : 'Voice'} Call` },
    contents: { en: `${callerName} is calling...` },
    existing_android_channel_id: isVideo ? 'onesignal_video_call_channel' : 'onesignal_audio_call_channel',
    priority: 10,
    ttl: 60,
    data: {
      type: 'call',
      callId,
      callerId: uid,
      callerName,
      callerAvatar: call.callerAvatar || null,
      callType: isVideo ? 'video' : 'audio',
      receiverId,
    },
    ios_sound: 'incoming_call.wav',
  });
  return { ok: true };
});
