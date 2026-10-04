// Destined push worker: replaces the Cloud Functions in functions/push.js
// (sendChatPush, sendCallPush, the missed-call push) on Firebase's Spark plan.
//
//   POST /chat-push {conversationId, messageId}
//   POST /call-push {receiverId, callId}
//   Authorization: Bearer <Firebase ID token>
//
// Every Firestore / RTDB read uses the caller's own ID token, so security
// rules apply. A check whose data the caller may not read is skipped, not
// failed (see README "Differences from push.js").

import {
  FORBIDDEN,
  HttpError,
  verifyIdToken,
  firestoreGet,
  firestoreFindByParticipants,
  rtdbGet,
  rtdbUpdate,
} from './firebase.js';
import { rateLimit, claimOnce, releaseClaim } from './limits.js';
import { callAllowed, stateFor, isMuted, isDeletedUser, pushBody, offerSendsVideo } from './rules.js';

const DEFAULT_ONESIGNAL_APP_ID = 'f4489084-4880-4e7f-aa6d-a3b0cfb8beb4';

const CHANNEL_CHAT = 'onesignal_chat_channel';
const CHANNEL_NEW_CHAT = 'onesignal_new_chat_channel'; // silent, low importance
const CHANNEL_AUDIO_CALL = 'onesignal_audio_call_channel';
const CHANNEL_VIDEO_CALL = 'onesignal_video_call_channel';
const IOS_CALL_SOUND = 'incoming_call.caf';

const MAX_BODY_BYTES = 4096;
const CALL_PUSH_MAX_AGE_MS = 90 * 1000;
const CHAT_MESSAGE_MAX_AGE_MS = 10 * 60 * 1000;
const CALL_PUSH_PER_MINUTE = 10;
const CHAT_PUSH_PER_MINUTE = 60;

// ---------- helpers ----------

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

function requireString(data, field, maxLength = 200) {
  const value = data && data[field];
  if (typeof value !== 'string' || value.length === 0 || value.length > maxLength || value.includes('/')) {
    throw new HttpError(400, `invalid-argument:${field}`);
  }
  return value;
}

async function readJsonBody(request) {
  const type = request.headers.get('content-type') || '';
  if (!/^application\/json\b/i.test(type)) throw new HttpError(415, 'unsupported-media-type');
  const declared = Number(request.headers.get('content-length') || 0);
  if (declared > MAX_BODY_BYTES) throw new HttpError(413, 'payload-too-large');
  const buf = await request.arrayBuffer();
  if (buf.byteLength > MAX_BODY_BYTES) throw new HttpError(413, 'payload-too-large');
  try {
    const data = JSON.parse(new TextDecoder().decode(buf));
    if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error('not an object');
    return data;
  } catch (_) {
    throw new HttpError(400, 'invalid-json');
  }
}

function bearer(request) {
  const h = request.headers.get('authorization') || '';
  const m = /^Bearer\s+(\S+)$/i.exec(h);
  if (!m) throw new HttpError(401, 'unauthenticated');
  return m[1];
}

function readable(v) {
  return v !== FORBIDDEN;
}

async function sendToOneSignal(env, payload) {
  const res = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      Authorization: `Basic ${env.ONESIGNAL_REST_API_KEY}`,
    },
    body: JSON.stringify({
      app_id: env.ONESIGNAL_APP_ID || DEFAULT_ONESIGNAL_APP_ID,
      target_channel: 'push',
      ...payload,
    }),
  });
  if (!res.ok) {
    console.error(`OneSignal error ${res.status}`);
    throw new HttpError(502, 'push-failed');
  }
}

// Name shown on the push: public_profiles first, then the caller's own users doc.
async function profileOf(ctx, uid) {
  const [pub, user] = await Promise.all([
    firestoreGet(ctx, ['public_profiles', uid]),
    firestoreGet(ctx, ['users', uid]),
  ]);
  const p = readable(pub) && pub ? pub : {};
  const u = readable(user) && user ? user : {};
  const pick = (...vals) => vals.find((v) => typeof v === 'string' && v.trim()) || null;
  return {
    name: String(pick(p.username, u.username, u.name) || 'Someone').slice(0, 60),
    avatar: pick(p.profileImage, p.avatar, u.profileImage, u.avatar),
  };
}

// Blocked either way. The caller reads its own blocked/{other} and the
// blockedBy/{other} mirror that the other user writes when blocking.
async function isBlockedBetween(ctx, uid, other) {
  const [blocked, blockedBy] = await Promise.all([
    firestoreGet(ctx, ['users', uid, 'blocked', other]),
    firestoreGet(ctx, ['users', uid, 'blockedBy', other]),
  ]);
  return (readable(blocked) && !!blocked) || (readable(blockedBy) && !!blockedBy);
}

// Receiver's push switches. users/{receiver} is owner-only, so this is
// normally unreadable and the check is skipped (returns null).
async function pushSettings(ctx, uid) {
  const user = await firestoreGet(ctx, ['users', uid]);
  if (!readable(user)) return null;
  if (!user) return { exists: false, push: false, messages: false };
  const s = user.notificationSettings && typeof user.notificationSettings === 'object' ? user.notificationSettings : {};
  return { exists: true, push: s.pushEnabled !== false, messages: s.messageNotifications !== false };
}

function chatChannel(conv, receiverId) {
  return stateFor(conv, receiverId) === 'active' ? CHANNEL_CHAT : CHANNEL_NEW_CHAT;
}

async function chatSkipReason(ctx, conv, senderId, receiverId) {
  if (isDeletedUser(conv, receiverId)) return 'receiver-deleted';
  if (isMuted(conv, receiverId)) return 'muted';
  const [blocked, settings] = await Promise.all([
    isBlockedBetween(ctx, senderId, receiverId),
    pushSettings(ctx, receiverId),
  ]);
  if (blocked) return 'blocked';
  if (settings && !settings.exists) return 'receiver-missing';
  if (settings && (!settings.push || !settings.messages)) return 'disabled';
  return null;
}

// ---------- POST /chat-push ----------

async function handleChatPush(ctx, env, data) {
  const conversationId = requireString(data, 'conversationId');
  const messageId = requireString(data, 'messageId');
  const uid = ctx.uid;
  rateLimit(uid, 'chat_push', CHAT_PUSH_PER_MINUTE);

  const [conv, msg] = await Promise.all([
    firestoreGet(ctx, ['conversations', conversationId]),
    firestoreGet(ctx, ['conversations', conversationId, 'messages', messageId]),
  ]);
  if (!readable(conv) || !readable(msg) || !conv || !msg || msg.senderId !== uid) {
    throw new HttpError(403, 'permission-denied');
  }

  if (msg.isDeleted === true) return { status: 'deleted' };
  const senderId = msg.senderId;
  const receiverId = msg.receiverId;
  const participants = Array.isArray(conv.participants) ? conv.participants : [];
  if (!receiverId || typeof receiverId !== 'string' || senderId === receiverId
      || !participants.includes(senderId) || !participants.includes(receiverId)) {
    throw new HttpError(403, 'permission-denied');
  }
  // No server-side receipts on Spark, so old messages cannot be replayed.
  if (msg.timestamp instanceof Date && Date.now() - msg.timestamp.getTime() > CHAT_MESSAGE_MAX_AGE_MS) {
    return { status: 'stale' };
  }

  const type = String(msg.type || 'text');
  const meta = msg.metadata && typeof msg.metadata === 'object' ? msg.metadata : {};
  if (type === 'call' && meta.callStatus === 'declined') return { status: 'declined' };

  const skip = await chatSkipReason(ctx, conv, senderId, receiverId);
  if (skip) return { status: skip };

  const key = type === 'call' && typeof meta.callId === 'string' && !meta.callId.includes('/')
    ? `missed_${meta.callId}`
    : `chat_${conversationId}_${messageId}`;
  if (!claimOnce(key)) return { status: 'duplicate' };

  try {
    const sender = await profileOf(ctx, senderId);
    if (type === 'call') {
      const isVideo = meta.callType === 'video';
      await sendToOneSignal(env, {
        include_aliases: { external_id: [receiverId] },
        headings: { en: sender.name },
        contents: { en: `Missed ${isVideo ? 'video' : 'audio'} call` },
        existing_android_channel_id: chatChannel(conv, receiverId),
        priority: 10,
        collapse_id: `chat_${conversationId}`.slice(0, 64),
        thread_id: conversationId,
        data: {
          type: 'missed_call',
          callId: typeof meta.callId === 'string' ? meta.callId : null,
          callerId: senderId,
          callType: isVideo ? 'video' : 'audio',
          receiverId,
          conversationId,
        },
      });
      return { status: 'sent' };
    }

    const silent = stateFor(conv, receiverId) !== 'active';
    await sendToOneSignal(env, {
      include_aliases: { external_id: [receiverId] },
      headings: { en: sender.name },
      contents: { en: pushBody(msg, String(env.SHOW_MESSAGE_TEXT).toLowerCase() === 'true') },
      existing_android_channel_id: chatChannel(conv, receiverId),
      priority: silent ? 5 : 10,
      ...(silent ? { ios_interruption_level: 'passive' } : {}),
      collapse_id: `chat_${conversationId}`.slice(0, 64),
      thread_id: conversationId,
      data: { type: 'new_message', conversationId, messageId, senderId, receiverId, messageType: type },
    });
    return { status: 'sent' };
  } catch (err) {
    releaseClaim(key);
    throw err;
  }
}

// ---------- POST /call-push ----------

// The 1:1 conversation: deterministic id first, then the legacy query.
async function findConversation(ctx, uidA, uidB) {
  const sorted = [uidA, uidB].sort();
  const direct = await firestoreGet(ctx, ['conversations', `${sorted[0]}_${sorted[1]}`]);
  if (readable(direct) && direct) return direct;
  return firestoreFindByParticipants(ctx, sorted);
}

// Ends a refused call so the caller stops ringing (same writes as push.js;
// the caller is allowed to make them).
async function refuseCall(ctx, receiverId, callId, hasRoom) {
  const updates = { [`incoming_calls/${receiverId}/${callId}`]: null };
  if (hasRoom) {
    updates[`rooms/${callId}/state`] = 'ended';
    updates[`rooms/${callId}/endReason`] = 'failed';
    updates[`rooms/${callId}/endedAt`] = { '.sv': 'timestamp' };
  }
  await rtdbUpdate(ctx, updates).catch(() => false);
}

async function handleCallPush(ctx, env, data) {
  const receiverId = requireString(data, 'receiverId');
  const callId = requireString(data, 'callId');
  const uid = ctx.uid;
  if (receiverId === uid || !callId.startsWith(`${uid}_`)) throw new HttpError(403, 'permission-denied');
  rateLimit(uid, 'call_push', CALL_PUSH_PER_MINUTE);

  const [inbox, room] = await Promise.all([
    rtdbGet(ctx, ['incoming_calls', receiverId, callId]),
    rtdbGet(ctx, ['rooms', callId]),
  ]);
  const deny = () => new HttpError(403, 'permission-denied');

  // The inbox is receiver-only under the current RTDB rules. When it is
  // unreadable, the room (which the caller can read) is the evidence.
  const inboxReadable = readable(inbox);
  if (inboxReadable && (!inbox || inbox.callerId !== uid || inbox.status !== 'ringing')) throw deny();
  if (!readable(room)) throw deny();

  const legacyId = callId.startsWith(`${uid}_${receiverId}_`);
  if (room) {
    if (room.callerId !== uid || room.calleeId !== receiverId
        || !['ringing', 'active'].includes(room.state)) throw deny();
    if (!inboxReadable && room.state !== 'ringing') throw deny();
  } else if (!legacyId || !inboxReadable) {
    throw deny();
  }

  const startedAt = inboxReadable ? inbox.timestamp : room.createdAt;
  if (typeof startedAt === 'number' && Date.now() - startedAt > CALL_PUSH_MAX_AGE_MS) {
    throw new HttpError(412, 'failed-precondition');
  }

  let isVideo;
  if (inboxReadable) {
    isVideo = inbox.callType === 'video';
  } else {
    isVideo = offerSendsVideo(room.offer && room.offer.sdp);
  }

  const [blocked, conv, settings] = await Promise.all([
    isBlockedBetween(ctx, uid, receiverId),
    findConversation(ctx, uid, receiverId),
    pushSettings(ctx, receiverId),
  ]);
  if (blocked || !conv || isDeletedUser(conv, receiverId)
      || !callAllowed(conv, uid, receiverId, isVideo ? 'video' : 'audio')) {
    await refuseCall(ctx, receiverId, callId, !!room);
    throw new HttpError(403, blocked ? 'blocked' : 'call-not-allowed');
  }
  if (settings && !settings.push) return { status: 'disabled' };

  const key = `call_${callId}`;
  if (!claimOnce(key)) return { status: 'duplicate' };

  try {
    const caller = await profileOf(ctx, uid);
    const inboxAvatar = inboxReadable && typeof inbox.callerAvatar === 'string' ? inbox.callerAvatar : null;
    await sendToOneSignal(env, {
      include_aliases: { external_id: [receiverId] },
      headings: { en: `Incoming ${isVideo ? 'Video' : 'Voice'} Call` },
      contents: { en: `${caller.name} is calling...` },
      existing_android_channel_id: isVideo ? CHANNEL_VIDEO_CALL : CHANNEL_AUDIO_CALL,
      priority: 10,
      ttl: 60,
      ios_interruption_level: 'time_sensitive',
      ios_sound: IOS_CALL_SOUND,
      data: {
        type: 'call',
        callId,
        callerId: uid,
        callerName: caller.name,
        callerAvatar: inboxAvatar || caller.avatar,
        callType: isVideo ? 'video' : 'audio',
        receiverId,
        conversationId: conv.id,
      },
    });
  } catch (err) {
    releaseClaim(key);
    throw err;
  }
  return { status: 'sent' };
}

// ---------- entry point ----------

const ROUTES = {
  '/chat-push': handleChatPush,
  '/call-push': handleCallPush,
};

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    const handler = ROUTES[pathname];
    if (!handler) return json(404, { ok: false, error: 'not-found' });
    if (request.method !== 'POST') return json(405, { ok: false, error: 'method-not-allowed' });

    try {
      if (!env.ONESIGNAL_REST_API_KEY || !env.FIREBASE_PROJECT_ID || !env.FIREBASE_DATABASE_URL) {
        throw new HttpError(500, 'worker-not-configured');
      }
      const idToken = bearer(request);
      const data = await readJsonBody(request);
      const uid = await verifyIdToken(idToken, env.FIREBASE_PROJECT_ID);
      const ctx = {
        uid,
        idToken,
        projectId: env.FIREBASE_PROJECT_ID,
        databaseUrl: env.FIREBASE_DATABASE_URL,
      };
      const result = await handler(ctx, env, data);
      return json(200, { ok: true, ...result });
    } catch (err) {
      if (err instanceof HttpError) return json(err.status, { ok: false, error: err.code });
      console.error(`push worker error: ${err && err.name}`);
      return json(500, { ok: false, error: 'internal' });
    }
  },
};
