const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  addDoc,
  deleteDoc,
  collection,
  query,
  where,
  writeBatch,
  serverTimestamp,
  increment,
  deleteField,
  Timestamp,
} = require('firebase/firestore');
const { createEnv } = require('./setup');

describe('firestore.rules', () => {
  let env;
  const db = (uid) => env.authenticatedContext(uid).firestore();

  before(async () => {
    env = await createEnv();
  });

  after(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      await setDoc(doc(fs, 'users/alice'), { uid: 'alice', username: 'Alice' });
      await setDoc(doc(fs, 'users/bob'), { uid: 'bob', username: 'Bob' });
      await setDoc(doc(fs, 'conversations/c1'), {
        participants: ['alice', 'bob'],
        isGroup: false,
        participantData: {},
        statePerUser: {},
      });
      await setDoc(doc(fs, 'conversations/c1/messages/m1'), {
        senderId: 'alice',
        receiverId: 'bob',
        conversationId: 'c1',
        message: 'hi',
        status: 'sent',
        isDeleted: false,
        timestamp: Timestamp.now(),
      });
      await setDoc(doc(fs, 'ludo_matches/l1'), {
        host: 'alice',
        players: { alice: { color: 'green' }, bob: { color: 'yellow' } },
        maxPlayers: 2,
        state: 'playing',
        dice: 1,
      });
    });
  });

  const newMessage = (over = {}) => ({
    senderId: 'alice',
    receiverId: 'bob',
    conversationId: 'c1',
    message: 'hello',
    type: 'text',
    status: 'sent',
    isDeleted: false,
    timestamp: serverTimestamp(),
    ...over,
  });

  describe('conversations', () => {
    it('non-participant cannot read a conversation', async () => {
      await assertFails(getDoc(doc(db('carol'), 'conversations/c1')));
    });

    it('participant can read the conversation and its messages', async () => {
      await assertSucceeds(getDoc(doc(db('bob'), 'conversations/c1')));
      await assertSucceeds(getDocs(collection(db('bob'), 'conversations/c1/messages')));
    });

    it('non-participant cannot read messages', async () => {
      await assertFails(getDocs(collection(db('carol'), 'conversations/c1/messages')));
    });

    it('messages of a not-yet-created pair conversation are readable only by the pair', async () => {
      await assertSucceeds(getDocs(collection(db('alice'), 'conversations/alice_bob/messages')));
      await assertFails(getDocs(collection(db('carol'), 'conversations/alice_bob/messages')));
    });

    it('list query must be scoped to my conversations', async () => {
      const mine = query(
        collection(db('alice'), 'conversations'),
        where('participants', 'array-contains', 'alice'),
      );
      await assertSucceeds(getDocs(mine));
      await assertFails(getDocs(collection(db('alice'), 'conversations')));
    });

    it('participants cannot be changed', async () => {
      await assertFails(
        updateDoc(doc(db('alice'), 'conversations/c1'), { participants: ['alice', 'carol'] }),
      );
    });

    it('first message can create a deterministic conversation in the same batch', async () => {
      const fs = db('alice');
      const batch = writeBatch(fs);
      batch.set(doc(fs, 'conversations/alice_carol/messages/x1'),
        newMessage({ receiverId: 'carol', conversationId: 'alice_carol' }));
      batch.set(doc(fs, 'conversations/alice_carol'), {
        participants: ['alice', 'carol'],
        isGroup: false,
      }, { merge: true });
      await assertSucceeds(batch.commit());
    });

    it('cannot squat a deterministic id that does not match participants', async () => {
      await assertFails(setDoc(doc(db('carol'), 'conversations/alice_bob'), {
        participants: ['alice', 'carol'],
        isGroup: false,
      }));
    });
  });

  describe('conversation updates (allow-list)', () => {
    const conv = (uid) => doc(db(uid), 'conversations/c1');

    // Same shape as ChatService._writeMessage.
    const sendBatch = (fs, { receiverState } = {}) => {
      const batch = writeBatch(fs);
      const msgRef = doc(collection(fs, 'conversations/c1/messages'));
      batch.set(msgRef, newMessage({
        id: msgRef.id,
        editedAt: null,
        readAt: null,
        deliveredAt: null,
        replyToMessageId: null,
        metadata: null,
      }));
      batch.set(doc(fs, 'conversations/c1'), {
        conversationId: 'c1',
        isGroup: false,
        lastMessage: { text: 'hello', type: 'text', senderId: 'alice', messageId: msgRef.id, at: serverTimestamp() },
        lastMessageAt: serverTimestamp(),
        participantData: { alice: { hasReplied: true }, bob: { unreadCount: increment(1) } },
        statePerUser: { alice: 'active', ...(receiverState ? { bob: receiverState } : {}) },
        typingAt: { alice: deleteField() },
      }, { merge: true });
      return batch.commit();
    };

    it('chat send batch is allowed', async () => {
      await assertSucceeds(sendBatch(db('alice'), { receiverState: 'new' }));
      await assertSucceeds(sendBatch(db('alice')));
    });

    it("sender cannot reset the receiver's state once set", async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations/c1'), { 'statePerUser.bob': 'active' });
      });
      await assertFails(sendBatch(db('alice'), { receiverState: 'new' }));
      await assertFails(updateDoc(conv('alice'), { 'statePerUser.bob': 'deleted' }));
    });

    it("receiver unread may only grow by one", async () => {
      await assertSucceeds(updateDoc(conv('alice'), { 'participantData.bob.unreadCount': increment(1) }));
      await assertFails(updateDoc(conv('alice'), { 'participantData.bob.unreadCount': increment(5) }));
      await assertFails(updateDoc(conv('alice'), { 'participantData.bob.unreadCount': 0 }));
    });

    it("cannot change the other user's mute, clear, consent or delete state", async () => {
      await assertFails(updateDoc(conv('alice'), { 'participantData.bob.muted': true }));
      await assertFails(updateDoc(conv('alice'), { 'participantData.bob.clearedBefore': serverTimestamp() }));
      await assertFails(updateDoc(conv('alice'), { 'participantData.bob.callEnabled.audio': true }));
      await assertFails(updateDoc(conv('alice'), { 'participantData.bob.deleted': true }));
      await assertFails(updateDoc(conv('alice'), { deletedUsers: ['bob'] }));
    });

    it('own read, clear, delete, mute, typing and call consent are allowed', async () => {
      const ref = conv('bob');
      await assertSucceeds(updateDoc(ref, {
        'participantData.bob.unreadCount': 0,
        'participantData.bob.lastReadAt': serverTimestamp(),
      }));
      await assertSucceeds(updateDoc(ref, {
        'participantData.bob.unreadCount': 0,
        'participantData.bob.lastReadAt': serverTimestamp(),
        'participantData.bob.clearedBefore': serverTimestamp(),
      }));
      await assertSucceeds(updateDoc(ref, {
        'statePerUser.bob': 'deleted',
        'participantData.bob.clearedBefore': serverTimestamp(),
      }));
      await assertSucceeds(updateDoc(ref, { 'participantData.bob.muted': true }));
      await assertSucceeds(updateDoc(ref, { 'typingAt.bob': serverTimestamp() }));
      await assertSucceeds(updateDoc(ref, { 'typingAt.bob': deleteField() }));
      await assertSucceeds(updateDoc(ref, { 'participantData.bob.callEnabled.video': true }));
      await assertFails(updateDoc(ref, { 'participantData.bob.callEnabled.screen': true }));
      await assertFails(updateDoc(ref, { 'typingAt.alice': serverTimestamp() }));
      await assertFails(updateDoc(ref, { 'participantData.bob.deleted': true }));
    });

    it('lastMessage must be my own message', async () => {
      await assertSucceeds(updateDoc(conv('alice'), {
        lastMessage: { text: 'edited', type: 'text', senderId: 'alice', messageId: 'm1', at: Timestamp.now() },
      }));
      await assertFails(updateDoc(conv('bob'), {
        lastMessage: { text: 'forged', type: 'text', senderId: 'alice', messageId: 'm1', at: Timestamp.now() },
      }));
    });

    it('unknown top-level fields are rejected', async () => {
      await assertFails(updateDoc(conv('alice'), { title: 'x' }));
    });

    it('legacy pair lookup by sorted participants is allowed', async () => {
      const q = query(
        collection(db('alice'), 'conversations'),
        where('participants', '==', ['alice', 'bob']),
        where('isGroup', '==', false),
      );
      await assertSucceeds(getDocs(q));
    });
  });

  describe('messages', () => {
    it('sender can create a message', async () => {
      await assertSucceeds(addDoc(collection(db('alice'), 'conversations/c1/messages'), newMessage()));
    });

    it("cannot create a message with someone else's senderId", async () => {
      await assertFails(addDoc(collection(db('alice'), 'conversations/c1/messages'),
        newMessage({ senderId: 'bob', receiverId: 'alice' })));
    });

    it('non-participant cannot post', async () => {
      await assertFails(addDoc(collection(db('carol'), 'conversations/c1/messages'),
        newMessage({ senderId: 'carol' })));
    });

    it('rejects text longer than 2000 characters', async () => {
      await assertFails(addDoc(collection(db('alice'), 'conversations/c1/messages'),
        newMessage({ message: 'x'.repeat(2001) })));
    });

    it('rejects a client-chosen timestamp', async () => {
      await assertFails(addDoc(collection(db('alice'), 'conversations/c1/messages'),
        newMessage({ timestamp: Timestamp.fromDate(new Date(2020, 0, 1)) })));
    });

    it('mediaUrl must point at our media hosts', async () => {
      await assertFails(addDoc(collection(db('alice'), 'conversations/c1/messages'),
        newMessage({ type: 'image', mediaUrl: 'https://evil.example.com/pixel.gif' })));
      await assertSucceeds(addDoc(collection(db('alice'), 'conversations/c1/messages'),
        newMessage({ type: 'image', mediaUrl: 'https://res.cloudinary.com/dekipip5j/image/upload/v1/a.jpg' })));
    });

    it('receiver cannot change the message text', async () => {
      await assertFails(updateDoc(doc(db('bob'), 'conversations/c1/messages/m1'), { message: 'forged' }));
    });

    it('receiver can mark the message read', async () => {
      await assertSucceeds(updateDoc(doc(db('bob'), 'conversations/c1/messages/m1'), {
        status: 'read',
        readAt: serverTimestamp(),
      }));
    });

    it('sender can edit and delete, but not change status or ids', async () => {
      const ref = doc(db('alice'), 'conversations/c1/messages/m1');
      await assertSucceeds(updateDoc(ref, { message: 'edited', editedAt: serverTimestamp() }));
      await assertSucceeds(updateDoc(ref, { isDeleted: true, message: '' }));
      await assertFails(updateDoc(ref, { status: 'read' }));
      await assertFails(updateDoc(ref, { receiverId: 'carol' }));
    });

    it('caller can log a missed call message with its summary', async () => {
      const fs = db('alice');
      const batch = writeBatch(fs);
      const msgRef = doc(collection(fs, 'conversations/c1/messages'));
      batch.set(msgRef, newMessage({
        id: msgRef.id,
        type: 'call',
        message: 'Missed audio call',
        metadata: { callId: 'alice_bob_1', callType: 'audio', callStatus: 'missed', duration: 0 },
        replyToMessageId: null,
        editedAt: null,
        readAt: null,
        deliveredAt: null,
      }));
      batch.update(doc(fs, 'conversations/c1'), {
        lastMessage: { text: 'Missed audio call', type: 'call', senderId: 'alice', messageId: msgRef.id, at: serverTimestamp() },
        lastMessageAt: serverTimestamp(),
        'participantData.bob.unreadCount': increment(1),
      });
      await assertSucceeds(batch.commit());
    });

    it('reply snapshots and message keys are allow-listed', async () => {
      await assertSucceeds(addDoc(collection(db('alice'), 'conversations/c1/messages'),
        newMessage({ replyToMessageId: 'm1', replyTo: { id: 'm1', senderId: 'alice', text: 'hi', type: 'text' } })));
      await assertFails(addDoc(collection(db('alice'), 'conversations/c1/messages'),
        newMessage({ replyTo: { id: 'm1', senderId: 'alice', text: 'hi', type: 'text', extra: 1 } })));
      await assertFails(addDoc(collection(db('alice'), 'conversations/c1/messages'),
        newMessage({ isAdminNotice: true })));
      await assertFails(addDoc(collection(db('alice'), 'conversations/c1/messages'),
        newMessage({ status: 'read' })));
    });

    it('blocked users cannot message each other (both directions)', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users/bob/blocked/alice'), { blockedAt: Timestamp.now() });
      });
      await assertFails(addDoc(collection(db('alice'), 'conversations/c1/messages'), newMessage()));
      await assertFails(addDoc(collection(db('bob'), 'conversations/c1/messages'),
        newMessage({ senderId: 'bob', receiverId: 'alice' })));
    });

    it('cannot message a deleted account', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations/c1'), { 'participantData.bob.deleted': true });
      });
      await assertFails(addDoc(collection(db('alice'), 'conversations/c1/messages'), newMessage()));
    });

    it('receiver may only move status forward', async () => {
      const ref = doc(db('bob'), 'conversations/c1/messages/m1');
      await assertFails(updateDoc(ref, { status: 'bogus' }));
      await assertSucceeds(updateDoc(ref, { status: 'delivered', deliveredAt: serverTimestamp() }));
      await assertFails(updateDoc(ref, { status: 'sent' }));
      await assertSucceeds(updateDoc(ref, { status: 'read', readAt: serverTimestamp() }));
      await assertFails(updateDoc(ref, { status: 'delivered' }));
    });

    it('messages cannot be hard-deleted by clients', async () => {
      await assertFails(deleteDoc(doc(db('alice'), 'conversations/c1/messages/m1')));
    });
  });

  describe('users', () => {
    it("cannot write another user's profile", async () => {
      await assertFails(updateDoc(doc(db('alice'), 'users/bob'), { bio: 'hacked' }));
    });

    it('owner can update allowed fields', async () => {
      await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), { bio: 'Hello' }, { merge: true }));
    });

    it('owner cannot set server-owned fields', async () => {
      await assertFails(setDoc(doc(db('alice'), 'users/alice'), { coins: 1000 }, { merge: true }));
      await assertFails(setDoc(doc(db('alice'), 'users/alice'), { isPremium: true }, { merge: true }));
    });

    it('caps free-text field length', async () => {
      await assertFails(setDoc(doc(db('alice'), 'users/alice'), { bio: 'x'.repeat(1001) }, { merge: true }));
    });

    it('block mirror is controlled by the blocker', async () => {
      await assertSucceeds(setDoc(doc(db('alice'), 'users/alice/blocked/bob'), { at: serverTimestamp() }));
      await assertSucceeds(setDoc(doc(db('alice'), 'users/bob/blockedBy/alice'), { at: serverTimestamp() }));
      await assertFails(deleteDoc(doc(db('bob'), 'users/bob/blockedBy/alice')));
      await assertFails(setDoc(doc(db('carol'), 'users/bob/blockedBy/alice'), { at: serverTimestamp() }));
    });

    it('users docs are owner-only to read', async () => {
      await assertSucceeds(getDoc(doc(db('alice'), 'users/alice')));
      await assertFails(getDoc(doc(db('bob'), 'users/alice')));
      await assertFails(getDocs(query(collection(db('bob'), 'users'), where('discoveryEnabled', '==', true))));
    });

    it('config/rules.legacyUsersRead re-opens signed-in reads', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'config/rules'), { legacyUsersRead: true });
      });
      await assertSucceeds(getDoc(doc(db('bob'), 'users/alice')));
      await assertFails(getDoc(doc(db('bob'), 'config/rules')));
    });

    it('DOB must be 18+ and cannot be changed once set', async () => {
      const ref = doc(db('alice'), 'users/alice');
      const years = (n) => Timestamp.fromDate(new Date(Date.now() - n * 365.25 * 24 * 3600 * 1000));
      await assertFails(setDoc(ref, { dateOfBirth: years(16) }, { merge: true }));
      await assertSucceeds(setDoc(ref, {
        dateOfBirth: years(25),
        dob: '01/01/2000',
        ageConfirmedAt: serverTimestamp(),
      }, { merge: true }));
      await assertFails(setDoc(ref, { dateOfBirth: years(30) }, { merge: true }));
      await assertFails(updateDoc(ref, { dateOfBirth: deleteField() }));
    });

    it('emailVerificationRequired cannot be cleared once set', async () => {
      const ref = doc(db('alice'), 'users/alice');
      await assertSucceeds(setDoc(ref, { emailVerificationRequired: true }, { merge: true }));
      await assertFails(setDoc(ref, { emailVerificationRequired: false }, { merge: true }));
    });

    it('server-owned deletion flags cannot be set by clients', async () => {
      await assertFails(setDoc(doc(db('alice'), 'users/alice'), { deleted: true }, { merge: true }));
    });

    it('public_profiles are read-only for clients', async () => {
      await assertSucceeds(getDoc(doc(db('alice'), 'public_profiles/bob')));
      await assertFails(setDoc(doc(db('alice'), 'public_profiles/alice'), { username: 'x' }));
    });
  });

  describe('reports', () => {
    it('reporter can create but nobody can read', async () => {
      await assertSucceeds(addDoc(collection(db('alice'), 'reports'), {
        reporterId: 'alice',
        reportedUserId: 'bob',
        reason: 'Spam',
        createdAt: serverTimestamp(),
      }));
      await assertFails(addDoc(collection(db('alice'), 'reports'), {
        reporterId: 'bob',
        reportedUserId: 'carol',
        reason: 'Spam',
      }));
      await assertFails(getDocs(collection(db('alice'), 'reports')));
    });
  });

  describe('games', () => {
    it('another player can claim a carrom queue entry only with a new match', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'carrom_queue/bob'), { uid: 'bob', displayName: 'Bob' });
      });
      const fs = db('alice');
      await assertFails(updateDoc(doc(fs, 'carrom_queue/bob'), { matchId: 'none', claimedBy: 'alice' }));
      const batch = writeBatch(fs);
      batch.set(doc(fs, 'carrom_matches/cm1'), {
        host: 'alice',
        players: { alice: {}, bob: {} },
        playerUids: ['alice', 'bob'],
        status: 'ready',
        turn: 'alice',
      });
      batch.update(doc(fs, 'carrom_queue/bob'), { matchId: 'cm1', claimedBy: 'alice' });
      await assertSucceeds(batch.commit());
    });

    it('either player may create a carrom rematch hosted by the other', async () => {
      await assertSucceeds(setDoc(doc(db('alice'), 'carrom_matches/cm2'), {
        host: 'bob',
        players: { alice: {}, bob: {} },
        playerUids: ['alice', 'bob'],
        status: 'ready',
        turn: 'bob',
      }));
    });

    it('non-player cannot update or delete a match', async () => {
      await assertFails(updateDoc(doc(db('carol'), 'ludo_matches/l1'), { dice: 6 }));
      await assertFails(deleteDoc(doc(db('carol'), 'ludo_matches/l1')));
    });

    it('player can write a move but cannot add players or fake dice', async () => {
      const ref = doc(db('bob'), 'ludo_matches/l1');
      await assertSucceeds(updateDoc(ref, { dice: 4, turnColor: 'green' }));
      await assertFails(updateDoc(ref, { dice: 9 }));
      await assertFails(updateDoc(ref, { 'players.carol': { color: 'blue' } }));
      await assertFails(updateDoc(ref, { host: 'bob' }));
    });

    it('match creator must be the host and a player', async () => {
      await assertFails(setDoc(doc(db('carol'), 'ludo_matches/l2'), {
        host: 'alice',
        players: { alice: {}, bob: {} },
        maxPlayers: 2,
        state: 'playing',
      }));
    });

    it("cannot write another user's leaderboard", async () => {
      await assertFails(setDoc(doc(db('alice'), 'leaderboards/carrom/allTime/bob'), {
        odZ: 'bob',
        score: increment(5),
        wins: increment(1),
        gamesPlayed: increment(1),
        updatedAt: serverTimestamp(),
      }, { merge: true }));
    });

    it('leaderboard increments are bounded', async () => {
      const ref = doc(db('alice'), 'leaderboards/carrom/allTime/alice');
      await assertFails(setDoc(ref, {
        odZ: 'alice',
        score: increment(1000),
        wins: increment(1),
        gamesPlayed: increment(1),
        updatedAt: serverTimestamp(),
      }, { merge: true }));
      await assertSucceeds(setDoc(ref, {
        odZ: 'alice',
        score: increment(9),
        wins: increment(1),
        gamesPlayed: increment(1),
        updatedAt: serverTimestamp(),
      }, { merge: true }));
    });

    it('stats must advance by exactly one game', async () => {
      const ref = doc(db('alice'), 'user_game_stats/alice/games/carrom');
      await assertFails(setDoc(ref, {
        totalGames: 50,
        wins: increment(50),
        losses: increment(0),
        draws: increment(0),
        totalScore: 500,
        lastPlayed: serverTimestamp(),
      }, { merge: true }));
      await assertSucceeds(setDoc(ref, {
        totalGames: 1,
        wins: increment(1),
        losses: increment(0),
        draws: increment(0),
        totalScore: 9,
        highScore: 9,
        lastPlayed: serverTimestamp(),
      }, { merge: true }));
    });

    it('matches are readable only by their players', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'ludo_matches/l1'), { playerUids: ['alice', 'bob'] });
      });
      await assertSucceeds(getDoc(doc(db('bob'), 'ludo_matches/l1')));
      await assertFails(getDoc(doc(db('carol'), 'ludo_matches/l1')));
      await assertSucceeds(getDocs(query(collection(db('alice'), 'ludo_matches'),
        where('playerUids', 'array-contains', 'alice'), where('state', '==', 'playing'))));
      await assertFails(getDocs(query(collection(db('alice'), 'ludo_matches'),
        where('state', '==', 'playing'))));
    });

    it('a queued host can claim ludo opponents while removing its own entry', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        await setDoc(doc(fs, 'ludo_queue/alice'), { uid: 'alice', playerCount: 2 });
        await setDoc(doc(fs, 'ludo_queue/bob'), { uid: 'bob', playerCount: 2 });
      });
      await assertFails(deleteDoc(doc(db('carol'), 'ludo_queue/bob')));
      await assertFails(deleteDoc(doc(db('alice'), 'ludo_queue/bob')));
      const fs = db('alice');
      const batch = writeBatch(fs);
      batch.delete(doc(fs, 'ludo_queue/alice'));
      batch.delete(doc(fs, 'ludo_queue/bob'));
      batch.set(doc(fs, 'ludo_matches/l9'), {
        host: 'alice',
        players: { alice: { color: 'green' }, bob: { color: 'yellow' } },
        playerUids: ['alice', 'bob'],
        maxPlayers: 2,
        state: 'playing',
        dice: 1,
      });
      await assertSucceeds(batch.commit());
    });

    it('carrom history is private to its owner', async () => {
      await assertSucceeds(getDocs(collection(db('alice'), 'user_game_stats/alice/carrom_history')));
      await assertFails(getDocs(collection(db('bob'), 'user_game_stats/alice/carrom_history')));
    });

    it("queue entries are created only for yourself", async () => {
      await assertFails(setDoc(doc(db('alice'), 'ludo_queue/bob'), {
        uid: 'bob',
        playerCount: 2,
        createdAt: serverTimestamp(),
      }));
      await assertSucceeds(setDoc(doc(db('alice'), 'ludo_queue/alice'), {
        uid: 'alice',
        playerCount: 2,
        createdAt: serverTimestamp(),
      }));
    });
  });

  it('unknown collections are denied', async () => {
    await assertFails(setDoc(doc(db('alice'), 'anything/x'), { a: 1 }));
    await assertFails(getDoc(doc(db('alice'), 'anything/x')));
  });
});
