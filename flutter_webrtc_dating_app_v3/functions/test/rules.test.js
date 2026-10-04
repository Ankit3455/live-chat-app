// Run: npm test (node:test, no Firebase SDKs needed).
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');

const { callAllowed, stateFor, isMuted, isDeletedUser, pushBody } = require('../conversation_rules');
const { parseCloudinaryUrl, cloudinarySignature, storagePath } = require('../media_utils');

const conv = (pd, extra = {}) => ({ participants: ['a', 'b'], participantData: pd, ...extra });

test('call is allowed only when both users enabled that type', () => {
  const both = conv({ a: { callEnabled: { audio: true } }, b: { callEnabled: { audio: true, video: true } } });
  assert.equal(callAllowed(both, 'a', 'b', 'audio'), true);
  assert.equal(callAllowed(both, 'a', 'b', 'video'), false);
  assert.equal(callAllowed(conv({ a: { callEnabled: { audio: true } } }), 'a', 'b', 'audio'), false);
  assert.equal(callAllowed(null, 'a', 'b', 'audio'), false);
});

test('state follows statePerUser, then legacy hasReplied/status', () => {
  assert.equal(stateFor(conv({}, { statePerUser: { b: 'active' } }), 'b'), 'active');
  assert.equal(stateFor(conv({ b: { hasReplied: true } }), 'b'), 'active');
  assert.equal(stateFor(conv({ b: { status: 'active' } }), 'b'), 'active');
  assert.equal(stateFor(conv({ b: {} }), 'b'), 'new');
});

test('mute and deleted-user resolution', () => {
  assert.equal(isMuted(conv({ b: { muted: true } }), 'b'), true);
  assert.equal(isMuted(conv({ b: { muted: false } }, { muted: { b: true } }), 'b'), false);
  assert.equal(isMuted(conv({}, { muted: { b: true } }), 'b'), true);
  assert.equal(isDeletedUser(conv({}, { deletedUsers: ['b'] }), 'b'), true);
  assert.equal(isDeletedUser(conv({ b: { deleted: true } }), 'b'), true);
  assert.equal(isDeletedUser(conv({}), 'b'), false);
});

test('push body hides text unless allowed and labels media', () => {
  assert.equal(pushBody({ type: 'text', message: 'hi' }, false), 'New message');
  assert.equal(pushBody({ type: 'text', message: 'hi' }, true), 'hi');
  assert.equal(pushBody({ type: 'image', message: '' }, true), 'Photo');
  assert.equal(pushBody({ type: 'image', message: 'look' }, true), 'Photo: look');
  assert.equal(pushBody({ type: 'audio', message: 'x' }, true), 'Voice message');
  assert.equal(pushBody({ type: 'call', message: 'Missed video call' }, false), 'Missed video call');
  assert.equal(pushBody({ type: 'text', message: 'x'.repeat(300) }, true).length, 120);
});

test('cloudinary urls parse to public ids', () => {
  assert.deepEqual(
    parseCloudinaryUrl('https://res.cloudinary.com/dekipip5j/image/upload/v1712345/chat/a_b/u_1.jpg'),
    { cloud: 'dekipip5j', resourceType: 'image', type: 'upload', publicId: 'chat/a_b/u_1' },
  );
  assert.equal(
    parseCloudinaryUrl('https://res.cloudinary.com/dekipip5j/video/upload/c_scale,w_10/v1/voices/x.m4a').publicId,
    'voices/x',
  );
  assert.equal(parseCloudinaryUrl('https://res.cloudinary.com/dekipip5j/raw/upload/v2/docs/a.pdf').publicId, 'docs/a.pdf');
  assert.equal(parseCloudinaryUrl('https://example.com/a.jpg'), null);
});

test('cloudinary signature sorts params and skips empty ones', () => {
  const expected = crypto.createHash('sha1').update('folder=f&public_id=p&timestamp=1s3cr3t').digest('hex');
  assert.equal(cloudinarySignature({ timestamp: '1', public_id: 'p', folder: 'f', upload_preset: '' }, 's3cr3t'), expected);
});

test('storage download urls map to object paths', () => {
  assert.equal(
    storagePath('https://firebasestorage.googleapis.com/v0/b/x.appspot.com/o/chat_media%2Fa_b%2F1.jpg?alt=media'),
    'chat_media/a_b/1.jpg',
  );
  assert.equal(storagePath('https://res.cloudinary.com/x'), null);
});
