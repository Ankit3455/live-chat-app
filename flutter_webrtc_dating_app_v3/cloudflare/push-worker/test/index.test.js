// Offline tests: `node --test` (Node 20+). fetch is mocked; no network.

import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

import worker from '../src/index.js';
import { resetJwksCache, decodeFields } from '../src/firebase.js';
import { resetState } from '../src/limits.js';
import { offerSendsVideo, pushBody } from '../src/rules.js';

const PROJECT = 'availchatproject';
const DB = 'https://availchatproject-default-rtdb.firebaseio.com';
const ENV = {
  FIREBASE_PROJECT_ID: PROJECT,
  FIREBASE_DATABASE_URL: DB,
  ONESIGNAL_APP_ID: 'app-id',
  ONESIGNAL_REST_API_KEY: 'rest-key',
  SHOW_MESSAGE_TEXT: 'false',
};
const ALICE = 'alice';
const BOB = 'bob';
const CONV_ID = 'alice_bob';

// ---------- signing ----------

const keyPair = await crypto.subtle.generateKey(
  { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
  true,
  ['sign', 'verify'],
);
const publicJwk = { ...(await crypto.subtle.exportKey('jwk', keyPair.publicKey)), kid: 'k1', alg: 'RS256', use: 'sig' };

const b64url = (bytes) => Buffer.from(bytes).toString('base64url');

async function makeToken(overrides = {}, header = { alg: 'RS256', kid: 'k1', typ: 'JWT' }) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: `https://securetoken.google.com/${PROJECT}`,
    aud: PROJECT,
    sub: ALICE,
    iat: now - 10,
    auth_time: now - 100,
    exp: now + 3000,
    ...overrides,
  };
  const input = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', keyPair.privateKey, new TextEncoder().encode(input));
  return `${input}.${b64url(new Uint8Array(sig))}`;
}

// ---------- Firestore / RTDB fixtures ----------

function encode(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(encode) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encode(x)])) } };
}

let docs; // firestore path -> data | 'FORBIDDEN'
let rtdb; // rtdb path -> value | 'FORBIDDEN'
let sent; // OneSignal payloads
let rtdbPatches;
let oneSignalStatus;

function defaultConv() {
  return {
    participants: [ALICE, BOB],
    participantData: {
      alice: { hasReplied: true, callEnabled: { audio: true, video: true } },
      bob: { hasReplied: true, callEnabled: { audio: true, video: true } },
    },
  };
}

beforeEach(() => {
  resetJwksCache();
  resetState();
  sent = [];
  rtdbPatches = [];
  oneSignalStatus = 200;
  docs = {
    [`conversations/${CONV_ID}`]: defaultConv(),
    [`conversations/${CONV_ID}/messages/m1`]: {
      senderId: ALICE, receiverId: BOB, type: 'text', message: 'secret hello', timestamp: new Date(),
    },
    'users/alice': { username: 'Alice' },
    'users/bob': 'FORBIDDEN',
  };
  rtdb = {
    [`incoming_calls/${BOB}/alice_c1`]: 'FORBIDDEN',
    'rooms/alice_c1': { callerId: ALICE, calleeId: BOB, state: 'ringing', createdAt: Date.now() },
  };
});

const FS_PREFIX = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/`;

globalThis.fetch = async (input, init = {}) => {
  const url = String(input);
  if (url.startsWith('https://www.googleapis.com/service_accounts/')) {
    return new Response(JSON.stringify({ keys: [publicJwk] }), {
      headers: { 'cache-control': 'public, max-age=19000' },
    });
  }
  if (url === 'https://onesignal.com/api/v1/notifications') {
    assert.equal(init.headers.Authorization, 'Basic rest-key');
    sent.push(JSON.parse(init.body));
    return new Response('{"id":"x"}', { status: oneSignalStatus });
  }
  if (url.endsWith(':runQuery')) return new Response('[{}]');
  if (url.startsWith(FS_PREFIX)) {
    assert.match(init.headers.Authorization, /^Bearer /);
    const path = url.slice(FS_PREFIX.length).split('/').map(decodeURIComponent).join('/');
    const d = docs[path];
    if (d === 'FORBIDDEN') return new Response('{}', { status: 403 });
    if (!d) return new Response('{}', { status: 404 });
    return new Response(JSON.stringify({ name: path, fields: encode(d).mapValue.fields }));
  }
  if (url.startsWith(DB)) {
    assert.match(url, /[?&]auth=/);
    if ((init.method || 'GET') === 'PATCH') {
      rtdbPatches.push(JSON.parse(init.body));
      return new Response('{}');
    }
    const path = new URL(url).pathname.replace(/^\//, '').replace(/\.json$/, '');
    const v = rtdb[decodeURIComponent(path)];
    if (v === 'FORBIDDEN') return new Response('{"error":"Permission denied"}', { status: 401 });
    return new Response(JSON.stringify(v === undefined ? null : v));
  }
  throw new Error(`unexpected fetch ${url}`);
};

async function call(path, body, { token, headers = {} } = {}) {
  const t = token === undefined ? await makeToken() : token;
  const req = new Request(`https://destined-push.example.workers.dev${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(t ? { authorization: `Bearer ${t}` } : {}), ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
  const res = await worker.fetch(req, ENV);
  return { status: res.status, body: await res.json() };
}

// ---------- auth & request validation ----------

test('rejects missing, forged, expired and wrong-project tokens', async () => {
  const body = { conversationId: CONV_ID, messageId: 'm1' };
  assert.equal((await call('/chat-push', body, { token: '' })).status, 401);
  assert.equal((await call('/chat-push', body, { token: await makeToken({ exp: 1 }) })).status, 401);
  assert.equal((await call('/chat-push', body, { token: await makeToken({ aud: 'other' }) })).status, 401);
  assert.equal((await call('/chat-push', body, { token: await makeToken({ iss: 'https://evil' }) })).status, 401);
  assert.equal((await call('/chat-push', body, { token: await makeToken({ sub: '' }) })).status, 401);
  const good = await makeToken();
  const forged = `${good.split('.').slice(0, 2).join('.')}.${b64url(new Uint8Array(256))}`;
  assert.equal((await call('/chat-push', body, { token: forged })).status, 401);
  assert.equal((await call('/chat-push', body, { token: await makeToken({}, { alg: 'none', kid: 'k1' }) })).status, 401);
  assert.equal(sent.length, 0);
});

test('rejects bad content type, big bodies, bad ids and wrong routes', async () => {
  assert.equal((await call('/chat-push', '{}', { headers: { 'content-type': 'text/plain' } })).status, 415);
  assert.equal((await call('/chat-push', { pad: 'x'.repeat(5000) })).status, 413);
  assert.equal((await call('/chat-push', { conversationId: 'a/b', messageId: 'm1' })).status, 400);
  assert.equal((await call('/nope', {})).status, 404);
});

// ---------- chat ----------

test('chat push: sends to the receiver without message text', async () => {
  const r = await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' });
  assert.deepEqual(r, { status: 200, body: { ok: true, status: 'sent' } });
  assert.equal(sent.length, 1);
  const p = sent[0];
  assert.deepEqual(p.include_aliases, { external_id: [BOB] });
  assert.equal(p.target_channel, 'push');
  assert.equal(p.app_id, 'app-id');
  assert.equal(p.existing_android_channel_id, 'onesignal_chat_channel');
  assert.equal(p.headings.en, 'Alice');
  assert.equal(p.contents.en, 'New message');
  assert.equal(p.data.type, 'new_message');
});

test('chat push: second call for the same message is a duplicate', async () => {
  await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' });
  const r = await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' });
  assert.equal(r.body.status, 'duplicate');
  assert.equal(sent.length, 1);
});

test('chat push: silent channel when the receiver has not replied', async () => {
  docs[`conversations/${CONV_ID}`].participantData.bob = {};
  await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' });
  assert.equal(sent[0].existing_android_channel_id, 'onesignal_new_chat_channel');
  assert.equal(sent[0].priority, 5);
  assert.equal(sent[0].ios_interruption_level, 'passive');
});

test('chat push: only the sender may trigger it', async () => {
  const r = await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' }, { token: await makeToken({ sub: BOB }) });
  assert.equal(r.status, 403);
  docs[`conversations/${CONV_ID}`] = 'FORBIDDEN';
  assert.equal((await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' })).status, 403);
  assert.equal(sent.length, 0);
});

test('chat push: skips muted, blocked and stale messages', async () => {
  docs[`conversations/${CONV_ID}`].participantData.bob.muted = true;
  assert.equal((await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' })).body.status, 'muted');
  docs[`conversations/${CONV_ID}`] = defaultConv();
  docs['users/alice/blockedBy/bob'] = { blockedAt: new Date() };
  assert.equal((await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' })).body.status, 'blocked');
  delete docs['users/alice/blockedBy/bob'];
  docs[`conversations/${CONV_ID}/messages/m1`].timestamp = new Date(Date.now() - 3600 * 1000);
  assert.equal((await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' })).body.status, 'stale');
  assert.equal(sent.length, 0);
});

test('chat push: call message becomes a missed-call push', async () => {
  docs[`conversations/${CONV_ID}/messages/m2`] = {
    senderId: ALICE, receiverId: BOB, type: 'call', message: 'Missed video call', timestamp: new Date(),
    metadata: { callId: 'alice_c1', callType: 'video', callStatus: 'missed' },
  };
  await call('/chat-push', { conversationId: CONV_ID, messageId: 'm2' });
  assert.equal(sent[0].data.type, 'missed_call');
  assert.equal(sent[0].contents.en, 'Missed video call');
});

test('chat push: OneSignal failure returns 502 and allows a retry', async () => {
  oneSignalStatus = 500;
  assert.equal((await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' })).status, 502);
  oneSignalStatus = 200;
  assert.equal((await call('/chat-push', { conversationId: CONV_ID, messageId: 'm1' })).body.status, 'sent');
});

// ---------- call ----------

const AUDIO_SDP = 'v=0\r\nm=audio 9 UDP\r\na=sendrecv\r\nm=video 9 UDP\r\na=recvonly\r\n';
const VIDEO_SDP = 'v=0\r\nm=audio 9 UDP\r\na=sendrecv\r\nm=video 9 UDP\r\na=sendrecv\r\n';

test('call push: room fallback when the inbox is unreadable', async () => {
  rtdb['rooms/alice_c1'].offer = { type: 'offer', sdp: VIDEO_SDP };
  const r = await call('/call-push', { receiverId: BOB, callId: 'alice_c1' });
  assert.deepEqual(r.body, { ok: true, status: 'sent' });
  const p = sent[0];
  assert.equal(p.existing_android_channel_id, 'onesignal_video_call_channel');
  assert.equal(p.ttl, 60);
  assert.equal(p.ios_sound, 'incoming_call.caf');
  assert.equal(p.data.type, 'call');
  assert.equal(p.data.conversationId, CONV_ID);
  assert.equal(p.contents.en, 'Alice is calling...');
});

test('call push: uses the inbox entry when readable', async () => {
  rtdb[`incoming_calls/${BOB}/alice_c1`] = {
    callerId: ALICE, status: 'ringing', callType: 'audio', timestamp: Date.now(), callerAvatar: 'https://a/x.png',
  };
  await call('/call-push', { receiverId: BOB, callId: 'alice_c1' });
  assert.equal(sent[0].existing_android_channel_id, 'onesignal_audio_call_channel');
  assert.equal(sent[0].data.callerAvatar, 'https://a/x.png');
});

test('call push: rejects foreign, old and not-ringing calls', async () => {
  assert.equal((await call('/call-push', { receiverId: BOB, callId: 'bob_c1' })).status, 403);
  rtdb['rooms/alice_c1'].state = 'ended';
  assert.equal((await call('/call-push', { receiverId: BOB, callId: 'alice_c1' })).status, 403);
  rtdb['rooms/alice_c1'] = { callerId: ALICE, calleeId: BOB, state: 'ringing', createdAt: Date.now() - 600000 };
  assert.equal((await call('/call-push', { receiverId: BOB, callId: 'alice_c1' })).status, 412);
  delete rtdb['rooms/alice_c1'];
  assert.equal((await call('/call-push', { receiverId: BOB, callId: 'alice_c1' })).status, 403);
  assert.equal(sent.length, 0);
});

test('call push: refuses and ends the call when not allowed', async () => {
  docs[`conversations/${CONV_ID}`].participantData.bob.callEnabled = { audio: false, video: false };
  rtdb['rooms/alice_c1'].offer = { type: 'offer', sdp: AUDIO_SDP };
  const r = await call('/call-push', { receiverId: BOB, callId: 'alice_c1' });
  assert.equal(r.status, 403);
  assert.equal(r.body.error, 'call-not-allowed');
  assert.equal(rtdbPatches.length, 1);
  assert.equal(rtdbPatches[0]['rooms/alice_c1/state'], 'ended');
  assert.equal(sent.length, 0);
});

test('call push: per-uid rate limit', async () => {
  let last;
  for (let i = 0; i < 11; i++) last = await call('/call-push', { receiverId: BOB, callId: `alice_x${i}` });
  assert.equal(last.status, 429);
});

// ---------- pure helpers ----------

test('helpers', () => {
  assert.equal(offerSendsVideo(AUDIO_SDP), false);
  assert.equal(offerSendsVideo(VIDEO_SDP), true);
  assert.equal(pushBody({ type: 'image', message: 'hi' }, false), 'Photo');
  assert.equal(pushBody({ type: 'game', message: 'secret', metadata: { game: 'rate', stage: 'invite' } }, true), "Let's play Rate It!");
  assert.equal(pushBody({ type: 'game', metadata: { game: 'flags', stage: 'result' } }, false), 'Red Flag, Green Flag: results are in');
  assert.equal(pushBody({ type: 'game', message: 'secret', metadata: { game: 'nope' } }, true), 'Game');
  assert.equal(pushBody({ type: 'game', metadata: { game: 'telepathy', stage: 'invite' } }, false), "Let's play Telepathy!");
  assert.equal(pushBody({ type: 'game', metadata: { game: 'chess', stage: 'result' } }, false), 'Chess: results are in');
  assert.equal(pushBody({ type: 'game', metadata: { game: 'tennis', stage: 'invite' } }, false), "Let's play Tennis Duel!");
  assert.equal(pushBody({ type: 'game', metadata: { game: 'thumb', stage: 'result' } }, false), 'Thumb War: results are in');
  assert.equal(pushBody({ type: 'text', message: ' hi ' }, true), 'hi');
  const d = decodeFields(encode({ a: [1, 'x'], b: { c: true }, t: new Date(0) }).mapValue.fields);
  assert.deepEqual(d.a, [1, 'x']);
  assert.equal(d.b.c, true);
  assert.equal(d.t.getTime(), 0);
});
