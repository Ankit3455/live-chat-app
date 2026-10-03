const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { ref, uploadBytes } = require('firebase/storage');
const { doc, setDoc } = require('firebase/firestore');
const { createEnv } = require('./setup');

describe('storage.rules', () => {
  let env;
  const storage = (uid) => env.authenticatedContext(uid).storage();
  const bytes = new Uint8Array([1, 2, 3]);

  before(async () => {
    env = await createEnv();
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'conversations/c1'), { participants: ['alice', 'bob'] });
    });
  });

  after(async () => {
    await env.cleanup();
  });

  it('voice intro is owner-only and must be audio', async () => {
    await assertSucceeds(uploadBytes(ref(storage('alice'), 'voices/alice/intro.m4a'), bytes,
      { contentType: 'audio/m4a' }));
    await assertFails(uploadBytes(ref(storage('bob'), 'voices/alice/intro.m4a'), bytes,
      { contentType: 'audio/m4a' }));
    await assertFails(uploadBytes(ref(storage('alice'), 'voices/alice/intro.m4a'), bytes,
      { contentType: 'text/html' }));
  });

  it('chat media is limited to conversation participants', async () => {
    await assertSucceeds(uploadBytes(ref(storage('alice'), 'chat_media/c1/img_1.jpg'), bytes,
      { contentType: 'image/jpeg' }));
    await assertFails(uploadBytes(ref(storage('carol'), 'chat_media/c1/img_2.jpg'), bytes,
      { contentType: 'image/jpeg' }));
  });

  it('avatars must be named after the uploader', async () => {
    await assertSucceeds(uploadBytes(ref(storage('alice'), 'avatars/alice_avatar_1.png'), bytes,
      { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(storage('alice'), 'avatars/bob_avatar_1.png'), bytes,
      { contentType: 'image/png' }));
  });

  it('unknown paths are denied', async () => {
    await assertFails(uploadBytes(ref(storage('alice'), 'misc/file.bin'), bytes));
  });
});
