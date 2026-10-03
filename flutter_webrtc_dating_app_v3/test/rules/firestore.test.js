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
