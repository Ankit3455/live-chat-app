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

    it('with consent enforcement on, ringing needs the server consent mirror', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await set(ref(ctx.database(), 'config/enforceCallConsent'), true);
      });
      const id = 'alice_bob_4';
      await assertFails(set(ref(rtdb('alice'), `incoming_calls/bob/${id}`), inboxEntry('alice', id)));

      await env.withSecurityRulesDisabled(async (ctx) => {
        await set(ref(ctx.database(), 'call_consent/bob/alice'), { audio: true, video: false });
      });
      await assertSucceeds(set(ref(rtdb('alice'), `incoming_calls/bob/${id}`), inboxEntry('alice', id)));
      const video = { ...inboxEntry('alice', 'alice_bob_5'), callType: 'video' };
      await assertFails(set(ref(rtdb('alice'), 'incoming_calls/bob/alice_bob_5'), video));
      // Closing an existing entry does not need consent.
      await assertSucceeds(update(ref(rtdb('alice'), `incoming_calls/bob/${id}`), { status: 'ended' }));
    });

    it('call consent mirror is server-only', async () => {
      await assertFails(set(ref(rtdb('alice'), 'call_consent/bob/alice'), { audio: true }));
      await assertFails(set(ref(rtdb('alice'), 'config/enforceCallConsent'), false));
      await assertSucceeds(get(ref(rtdb('bob'), 'call_consent/bob/alice')));
      await assertFails(get(ref(rtdb('carol'), 'call_consent/bob/alice')));
    });

    it('only the owner reads the inbox', async () => {
      await assertFails(get(ref(rtdb('alice'), 'incoming_calls/bob')));
      await assertSucceeds(get(ref(rtdb('bob'), 'incoming_calls/bob')));
    });
  });

  it('a caller can read only their own entry in the callee inbox', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.database();
      await set(ref(db, 'incoming_calls/bob/alice_bob_1'), { callerId: 'alice', status: 'ringing' });
      await set(ref(db, 'incoming_calls/bob/carol_bob_1'), { callerId: 'carol', status: 'ringing' });
    });
    await assertSucceeds(get(ref(rtdb('alice'), 'incoming_calls/bob/alice_bob_1')));
    await assertFails(get(ref(rtdb('alice'), 'incoming_calls/bob/carol_bob_1')));
    await assertFails(get(ref(rtdb('alice'), 'incoming_calls/bob')));
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

    it('each participant writes only its own short video filter', async () => {
      await assertSucceeds(set(ref(rtdb('alice'), `rooms/${id}/filters/alice`), 'warm'));
      await assertSucceeds(set(ref(rtdb('bob'), `rooms/${id}/filters/bob`), 'bw'));
      await assertFails(set(ref(rtdb('alice'), `rooms/${id}/filters/bob`), 'warm'));
      await assertFails(set(ref(rtdb('carol'), `rooms/${id}/filters/carol`), 'warm'));
      await assertFails(set(ref(rtdb('alice'), `rooms/${id}/filters/alice`), 'x'.repeat(21)));
      await assertFails(set(ref(rtdb('alice'), `rooms/${id}/filters/alice`), 7));
      await assertFails(set(ref(rtdb('alice'), `rooms/${id}/filters`), { alice: 'warm', bob: 'cool' }));
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

  describe('account deletion and stale cleanup (client side)', () => {
    it('owner can remove its presence node; others cannot', async () => {
      await assertSucceeds(set(ref(rtdb('alice'), 'presence/alice'), { online: true, lastSeen: serverTimestamp() }));
      await assertFails(remove(ref(rtdb('bob'), 'presence/alice')));
      await assertSucceeds(remove(ref(rtdb('alice'), 'presence/alice')));
    });

    it('owner can remove its whole incoming_calls node', async () => {
      await assertSucceeds(set(ref(rtdb('alice'), 'incoming_calls/bob/alice_bob_10'), inboxEntry('alice', 'alice_bob_10')));
      await assertSucceeds(set(ref(rtdb('carol'), 'incoming_calls/bob/carol_bob_10'), inboxEntry('carol', 'carol_bob_10')));
      await assertFails(remove(ref(rtdb('alice'), 'incoming_calls/bob')));
      await assertSucceeds(remove(ref(rtdb('bob'), 'incoming_calls/bob')));
    });

    it('callee can remove stale entries in its own inbox', async () => {
      await assertSucceeds(set(ref(rtdb('alice'), 'incoming_calls/bob/alice_bob_11'), inboxEntry('alice', 'alice_bob_11')));
      await assertSucceeds(set(ref(rtdb('carol'), 'incoming_calls/bob/carol_bob_11'), inboxEntry('carol', 'carol_bob_11')));
      await assertSucceeds(update(ref(rtdb('bob'), 'incoming_calls/bob'), {
        alice_bob_11: null,
        carol_bob_11: null,
      }));
    });

    it("caller can remove only its own entry in someone else's inbox", async () => {
      await assertSucceeds(set(ref(rtdb('alice'), 'incoming_calls/bob/alice_bob_12'), inboxEntry('alice', 'alice_bob_12')));
      await assertSucceeds(set(ref(rtdb('carol'), 'incoming_calls/bob/carol_bob_12'), inboxEntry('carol', 'carol_bob_12')));
      await assertFails(remove(ref(rtdb('alice'), 'incoming_calls/bob/carol_bob_12')));
      await assertSucceeds(remove(ref(rtdb('alice'), 'incoming_calls/bob/alice_bob_12')));
    });

    it('owner can remove its astrology answers; others cannot', async () => {
      await assertSucceeds(set(ref(rtdb('alice'), 'users/alice'), { luckyNumber: 7 }));
      await assertFails(remove(ref(rtdb('bob'), 'users/alice')));
      await assertSucceeds(remove(ref(rtdb('alice'), 'users/alice')));
    });

    it('a participant can remove a room by id; a stranger cannot', async () => {
      await assertSucceeds(set(ref(rtdb('alice'), 'rooms/alice_r1'), room('alice', 'bob')));
      await assertFails(remove(ref(rtdb('carol'), 'rooms/alice_r1')));
      await assertSucceeds(remove(ref(rtdb('alice'), 'rooms/alice_r1')));
    });
  });

  it('users/{uid} is owner-only', async () => {
    await assertSucceeds(update(ref(rtdb('alice'), 'users/alice'), { luckyNumber: 7 }));
    await assertFails(get(ref(rtdb('bob'), 'users/alice')));
    await assertFails(update(ref(rtdb('bob'), 'users/alice'), { luckyNumber: 1 }));
  });
});
