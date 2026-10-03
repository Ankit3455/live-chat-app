const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { ref, set, get, update, remove, serverTimestamp } = require('firebase/database');
const { createEnv } = require('./setup');

describe('database.rules.json', () => {
  let env;
  const rtdb = (uid) => env.authenticatedContext(uid).database();

  const inboxEntry = (callerId, callId) => ({
    status: 'ringing',
    roomId: callId,
    callType: 'audio',
    callerId,
    callerName: 'Caller',
    timestamp: serverTimestamp(),
  });

  const room = (callerId, calleeId) => ({
    state: 'ringing',
    callerId,
    calleeId,
    createdAt: serverTimestamp(),
  });

  before(async () => {
    env = await createEnv();
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearDatabase();
  });

  describe('incoming_calls', () => {
    it('cannot write an inbox entry with a fake callerId', async () => {
      const id = 'carol_bob_1';
      await assertFails(set(ref(rtdb('carol'), `incoming_calls/bob/${id}`), inboxEntry('alice', id)));
    });

    it('caller can ring with a callId prefixed by its uid and the callee uid', async () => {
      const id = 'alice_bob_1';
      await assertSucceeds(set(ref(rtdb('alice'), `incoming_calls/bob/${id}`), inboxEntry('alice', id)));
    });

    it('callId must belong to the caller unless the room proves it', async () => {
      const id = 'random-uuid-1';
      await assertFails(set(ref(rtdb('alice'), `incoming_calls/bob/${id}`), inboxEntry('alice', id)));
      await assertSucceeds(set(ref(rtdb('alice'), `rooms/${id}`), room('alice', 'bob')));
      await assertSucceeds(set(ref(rtdb('alice'), `incoming_calls/bob/${id}`), inboxEntry('alice', id)));
    });

    it("caller cannot overwrite someone else's ringing entry", async () => {
      const id = 'alice_bob_2';
      await assertSucceeds(set(ref(rtdb('alice'), `incoming_calls/bob/${id}`), inboxEntry('alice', id)));
      await assertFails(update(ref(rtdb('carol'), `incoming_calls/bob/${id}`), { callerName: 'Mallory' }));
    });

    it('caller can close and remove its own entry; callee can remove any', async () => {
      const id = 'alice_bob_3';
      await assertSucceeds(set(ref(rtdb('alice'), `incoming_calls/bob/${id}`), inboxEntry('alice', id)));
      await assertSucceeds(update(ref(rtdb('alice'), `incoming_calls/bob/${id}`), { status: 'missed' }));
      await assertSucceeds(remove(ref(rtdb('alice'), `incoming_calls/bob/${id}`)));
      await assertSucceeds(set(ref(rtdb('alice'), `incoming_calls/bob/${id}`), inboxEntry('alice', id)));
      await assertSucceeds(remove(ref(rtdb('bob'), `incoming_calls/bob/${id}`)));
    });

    it('only the owner reads the inbox', async () => {
      await assertFails(get(ref(rtdb('alice'), 'incoming_calls/bob')));
      await assertSucceeds(get(ref(rtdb('bob'), 'incoming_calls/bob')));
    });
  });

  describe('rooms', () => {
    const id = 'alice_bob_9';

    beforeEach(async () => {
      await set(ref(rtdb('alice'), `rooms/${id}`), room('alice', 'bob'));
    });

    it('only caller and callee read or write the room', async () => {
      await assertFails(get(ref(rtdb('carol'), `rooms/${id}`)));
      await assertFails(set(ref(rtdb('carol'), `rooms/${id}/state`), 'ended'));
      await assertSucceeds(get(ref(rtdb('bob'), `rooms/${id}`)));
      await assertSucceeds(set(ref(rtdb('bob'), `rooms/${id}/state`), 'accepted'));
    });

    it('offer is caller-only and answer is callee-only', async () => {
      await assertSucceeds(set(ref(rtdb('alice'), `rooms/${id}/offer`), { type: 'offer', sdp: 'x' }));
      await assertFails(set(ref(rtdb('bob'), `rooms/${id}/offer`), { type: 'offer', sdp: 'y' }));
      await assertSucceeds(set(ref(rtdb('bob'), `rooms/${id}/answer`), { type: 'answer', sdp: 'z' }));
      await assertFails(set(ref(rtdb('alice'), `rooms/${id}/answer`), { type: 'answer', sdp: 'z' }));
    });

    it('participants cannot be swapped and strangers cannot hijack the room', async () => {
      await assertFails(set(ref(rtdb('alice'), `rooms/${id}/calleeId`), 'carol'));
      await assertFails(set(ref(rtdb('carol'), `rooms/${id}`), room('carol', 'bob')));
    });

    it('end-of-call update with reason is allowed for participants', async () => {
      await assertSucceeds(update(ref(rtdb('bob'), `rooms/${id}`), {
        state: 'ended',
        endReason: 'declined',
        endedBy: 'bob',
        endedAt: serverTimestamp(),
      }));
      await assertSucceeds(remove(ref(rtdb('alice'), `rooms/${id}`)));
    });
  });

  it('users/{uid} is owner-only', async () => {
    await assertSucceeds(update(ref(rtdb('alice'), 'users/alice'), { luckyNumber: 7 }));
    await assertFails(get(ref(rtdb('bob'), 'users/alice')));
    await assertFails(update(ref(rtdb('bob'), 'users/alice'), { luckyNumber: 1 }));
  });
});
