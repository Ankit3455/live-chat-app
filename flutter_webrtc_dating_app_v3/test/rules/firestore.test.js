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
  arrayUnion,
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

    it('public_profiles are readable and reject writes without uid/updatedAt', async () => {
      await assertSucceeds(getDoc(doc(db('alice'), 'public_profiles/bob')));
      await assertFails(setDoc(doc(db('alice'), 'public_profiles/alice'), { username: 'x' }));
    });
  });

  describe('public_profiles (client-written mirror)', () => {
    // Shape of PublicProfile.fromUserData + updatedAt.
    const mirror = (uid, over = {}) => ({
      uid,
      username: 'Alice',
      profileImage: 'https://res.cloudinary.com/dekipip5j/image/upload/v1/a.jpg',
      avatar: 'https://api.dicebear.com/7.x/x.svg',
      avatarVersion: 2,
      bio: 'Hello',
      interests: ['music', 'travel'],
      zodiacSign: 'Leo',
      location: 'Pune',
      voiceIntroDurationSeconds: 12,
      profession: 'Engineer',
      hereFor: ['dating'],
      height: '170',
      believesInAstrology: true,
      astrologyBeliefLevel: 3,
      online: true,
      lastSeen: serverTimestamp(),
      gender: 'female',
      avatarProperties: { avatarImageUrl: 'https://res.cloudinary.com/dekipip5j/image/upload/v1/av.png' },
      age: 25,
      geohash: 'tek2m',
      discoveryEnabled: true,
      updatedAt: serverTimestamp(),
      ...over,
    });
    const ref = (uid, as = uid) => doc(db(as), `public_profiles/${uid}`);

    it('owner can create, replace, merge and delete its own mirror', async () => {
      await assertSucceeds(setDoc(ref('alice'), mirror('alice')));
      await assertSucceeds(setDoc(ref('alice'), mirror('alice', { bio: 'New bio', online: false })));
      await assertSucceeds(setDoc(ref('alice'),
        { online: false, lastSeen: serverTimestamp(), updatedAt: serverTimestamp() }, { merge: true }));
      await assertSucceeds(updateDoc(ref('alice'),
        { age: deleteField(), discoveryEnabled: false, updatedAt: serverTimestamp() }));
      await assertSucceeds(deleteDoc(ref('alice')));
    });

    it('a minimal mirror (uid, discoveryEnabled, updatedAt) is allowed', async () => {
      await assertSucceeds(setDoc(ref('alice'),
        { uid: 'alice', discoveryEnabled: false, updatedAt: serverTimestamp() }));
    });

    it("cannot write or delete someone else's mirror", async () => {
      await assertFails(setDoc(ref('bob', 'alice'), mirror('bob')));
      await assertFails(setDoc(ref('alice', 'bob'), mirror('alice')));
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'public_profiles/bob'), { uid: 'bob', updatedAt: Timestamp.now() });
      });
      await assertFails(deleteDoc(ref('bob', 'alice')));
      await assertFails(updateDoc(ref('bob', 'alice'), { bio: 'x', updatedAt: serverTimestamp() }));
    });

    it('uid field must match the doc id', async () => {
      await assertFails(setDoc(ref('alice'), mirror('alice', { uid: 'bob' })));
      const noUid = mirror('alice');
      delete noUid.uid;
      await assertFails(setDoc(ref('alice'), noUid));
    });

    it('updatedAt must be the server time on every write', async () => {
      await assertFails(setDoc(ref('alice'), mirror('alice', { updatedAt: Timestamp.fromDate(new Date(2020, 0, 1)) })));
      const noTs = mirror('alice');
      delete noTs.updatedAt;
      await assertFails(setDoc(ref('alice'), noTs));
      await assertSucceeds(setDoc(ref('alice'), mirror('alice')));
      await assertFails(updateDoc(ref('alice'), { bio: 'no timestamp' }));
    });

    it('unknown keys are rejected', async () => {
      await assertFails(setDoc(ref('alice'), mirror('alice', { isPremium: true })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { coins: 100 })));
      await assertFails(setDoc(ref('alice'), mirror('alice', {
        avatarProperties: { avatarImageUrl: 'https://x/y.png', skinColor: 'f0c' },
      })));
    });

    it('private fields are rejected', async () => {
      const privateFields = {
        email: 'a@example.com',
        dateOfBirth: Timestamp.fromDate(new Date(2000, 0, 1)),
        dob: '01/01/2000',
        birthTime: '10:30',
        birthLocation: 'Mumbai',
        placeOfBirth: 'Mumbai',
        lat: 18.5,
        lng: 73.8,
        latitude: 18.5,
        longitude: 73.8,
        userLatitude: 18.5,
        userLongitude: 73.8,
        fcmTokens: ['t1'],
        notificationSettings: { chat: true },
        notificationsEnabled: true,
        settings: { theme: 'dark' },
      };
      for (const [key, value] of Object.entries(privateFields)) {
        await assertFails(setDoc(ref('alice'), mirror('alice', { [key]: value })));
      }
      await assertSucceeds(setDoc(ref('alice'), mirror('alice')));
      await assertFails(setDoc(ref('alice'),
        { email: 'a@example.com', updatedAt: serverTimestamp() }, { merge: true }));
    });

    it('string and list caps match the users rules', async () => {
      await assertFails(setDoc(ref('alice'), mirror('alice', { username: 'x'.repeat(101) })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { bio: 'x'.repeat(1001) })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { profession: 'x'.repeat(151) })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { location: 'x'.repeat(101) })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { profileImage: 'https://x/' + 'a'.repeat(2048) })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { voiceIntroUrl: 'https://x/' + 'a'.repeat(2048) })));
      await assertFails(setDoc(ref('alice'), mirror('alice', {
        avatarProperties: { avatarImageUrl: 'https://x/' + 'a'.repeat(2048) },
      })));
      await assertFails(setDoc(ref('alice'), mirror('alice', {
        interests: Array.from({ length: 31 }, (_, i) => `i${i}`),
      })));
      await assertSucceeds(setDoc(ref('alice'), mirror('alice', {
        username: 'x'.repeat(100),
        bio: 'x'.repeat(1000),
        interests: Array.from({ length: 30 }, (_, i) => `i${i}`),
      })));
    });

    it('derived fields are type- and range-checked', async () => {
      await assertFails(setDoc(ref('alice'), mirror('alice', { age: 17 })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { age: 121 })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { age: 25.5 })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { age: '25' })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { geohash: 'tek2m4x6vrt9q' })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { geohash: 12345 })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { online: 'yes' })));
      await assertFails(setDoc(ref('alice'), mirror('alice', { discoveryEnabled: 1 })));
      await assertFails(setDoc(ref('alice'), mirror('alice', {
        lastSeen: Timestamp.fromDate(new Date(Date.now() + 365 * 24 * 3600 * 1000)),
      })));
      await assertSucceeds(setDoc(ref('alice'), mirror('alice', {
        age: 18,
        lastSeen: Timestamp.fromDate(new Date(2024, 0, 1)),
      })));
      await assertSucceeds(setDoc(ref('alice'), mirror('alice', { age: 120 })));
    });

    it('discoveryEnabled true requires a known adult age', async () => {
      const noAge = mirror('alice');
      delete noAge.age;
      await assertFails(setDoc(ref('alice'), noAge));
      await assertSucceeds(setDoc(ref('alice'), { ...noAge, discoveryEnabled: false }));
      await assertSucceeds(setDoc(ref('alice'), mirror('alice')));
      await assertFails(updateDoc(ref('alice'), { age: deleteField(), updatedAt: serverTimestamp() }));
    });

    it('signed-out users cannot read; signed-in users can', async () => {
      await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'public_profiles/alice')));
      await assertSucceeds(getDoc(doc(db('bob'), 'public_profiles/alice')));
    });
  });

  describe('account deletion (client side)', () => {
    const conv = (uid) => doc(db(uid), 'conversations/c1');

    beforeEach(async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations/c1'), {
          'participantData.alice': { hasReplied: true, unreadCount: 0 },
          'participantData.bob': { hasReplied: true, unreadCount: 3, muted: true },
          'statePerUser.alice': 'active',
          'statePerUser.bob': 'active',
          'typingAt.alice': Timestamp.now(),
          'typingAt.bob': Timestamp.now(),
        });
      });
    });

    // Same shape as functions/account.js anonymiseConversations.
    const markDeleted = (uid, over = {}) => ({
      deletedUsers: arrayUnion(uid),
      [`participantData.${uid}`]: { deleted: true, unreadCount: 0 },
      [`statePerUser.${uid}`]: deleteField(),
      [`typingAt.${uid}`]: deleteField(),
      ...over,
    });

    it('participant can mark itself deleted in a conversation', async () => {
      await assertSucceeds(updateDoc(conv('bob'), markDeleted('bob')));
    });

    it('the other participant can mark itself deleted afterwards too', async () => {
      await assertSucceeds(updateDoc(conv('bob'), markDeleted('bob')));
      await assertSucceeds(updateDoc(conv('alice'), markDeleted('alice')));
    });

    it('works when statePerUser/typingAt entries are absent', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations/c1'), {
          'statePerUser.bob': deleteField(),
          'typingAt.bob': deleteField(),
        });
      });
      await assertSucceeds(updateDoc(conv('bob'), markDeleted('bob')));
    });

    it('participantData.<me> must be exactly {deleted: true, unreadCount: 0}', async () => {
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', {
        'participantData.bob': { deleted: true, unreadCount: 0, muted: true },
      })));
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', {
        'participantData.bob': { deleted: true },
      })));
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', {
        'participantData.bob': { deleted: false, unreadCount: 0 },
      })));
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', {
        'participantData.bob': { deleted: true, unreadCount: 5 },
      })));
      // Field-path merge keeps the old keys (hasReplied, muted), so it is not exact.
      await assertFails(updateDoc(conv('bob'), {
        deletedUsers: arrayUnion('bob'),
        'participantData.bob.deleted': true,
        'participantData.bob.unreadCount': 0,
        'statePerUser.bob': deleteField(),
        'typingAt.bob': deleteField(),
      }));
    });

    it('cannot mark the other participant deleted', async () => {
      await assertFails(updateDoc(conv('alice'), markDeleted('bob')));
      await assertFails(updateDoc(conv('alice'), {
        deletedUsers: arrayUnion('bob'),
        'participantData.alice': { deleted: true, unreadCount: 0 },
      }));
      await assertFails(updateDoc(conv('alice'), markDeleted('alice', {
        deletedUsers: arrayUnion('alice', 'bob'),
      })));
    });

    it('cannot replace deletedUsers instead of appending', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(doc(ctx.firestore(), 'conversations/c1'), { deletedUsers: ['legacy'] });
      });
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', { deletedUsers: ['bob'] })));
      await assertSucceeds(updateDoc(conv('bob'), markDeleted('bob', { deletedUsers: ['legacy', 'bob'] })));
    });

    it('participantData.<me> cannot be set without joining deletedUsers', async () => {
      const noList = markDeleted('bob');
      delete noList.deletedUsers;
      await assertFails(updateDoc(conv('bob'), noList));
    });

    it("cannot touch other keys or the other user's entries in the same write", async () => {
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', { lastMessageAt: serverTimestamp() })));
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', { participants: ['alice', 'bob'].reverse() })));
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', { title: 'gone' })));
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', { 'participantData.alice.muted': true })));
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', { 'statePerUser.alice': deleteField() })));
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', { 'typingAt.alice': deleteField() })));
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', { 'statePerUser.bob': 'deleted' })));
      await assertFails(updateDoc(conv('bob'), markDeleted('bob', { 'typingAt.bob': serverTimestamp() })));
    });

    it('non-participant cannot use the deletion update', async () => {
      await assertFails(updateDoc(conv('carol'), markDeleted('carol')));
    });

    it('conversations still cannot be deleted by clients', async () => {
      await assertFails(deleteDoc(conv('bob')));
    });

    it('owner can delete its users doc and owner subcollections', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        await setDoc(doc(fs, 'users/bob/blocked/carol'), { blockedAt: Timestamp.now() });
        await setDoc(doc(fs, 'users/bob/blockedBy/alice'), { blockedAt: Timestamp.now() });
        await setDoc(doc(fs, 'users/bob/settings/main'), { theme: 'dark' });
      });
      await assertSucceeds(deleteDoc(doc(db('bob'), 'users/bob/blocked/carol')));
      await assertSucceeds(deleteDoc(doc(db('bob'), 'users/bob/settings/main')));
      // blockedBy only once the profile doc is gone (same batch or after).
      await assertFails(deleteDoc(doc(db('bob'), 'users/bob/blockedBy/alice')));
      const fs = db('bob');
      const batch = writeBatch(fs);
      batch.delete(doc(fs, 'users/bob'));
      batch.delete(doc(fs, 'users/bob/blockedBy/alice'));
      await assertSucceeds(batch.commit());
    });

    it('owner can delete blockedBy after deleting the users doc', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users/bob/blockedBy/alice'), { blockedAt: Timestamp.now() });
      });
      await assertSucceeds(deleteDoc(doc(db('bob'), 'users/bob')));
      await assertSucceeds(deleteDoc(doc(db('bob'), 'users/bob/blockedBy/alice')));
    });

    it("cannot delete another user's doc or subcollections", async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'users/alice/blocked/carol'), { blockedAt: Timestamp.now() });
      });
      await assertFails(deleteDoc(doc(db('bob'), 'users/alice')));
      await assertFails(deleteDoc(doc(db('bob'), 'users/alice/blocked/carol')));
    });

    it('may remove its own blockedBy mirror in others, but not their blocked list', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        await setDoc(doc(fs, 'users/alice/blockedBy/bob'), { blockedAt: Timestamp.now() });
        await setDoc(doc(fs, 'users/alice/blocked/bob'), { blockedAt: Timestamp.now() });
        await setDoc(doc(fs, 'users/alice/blockedBy/carol'), { blockedAt: Timestamp.now() });
      });
      await assertSucceeds(deleteDoc(doc(db('bob'), 'users/alice/blockedBy/bob')));
      await assertFails(deleteDoc(doc(db('bob'), 'users/alice/blocked/bob')));
      await assertFails(deleteDoc(doc(db('bob'), 'users/alice/blockedBy/carol')));
    });

    it('owner can delete its game stats, history and leaderboard rows', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        await setDoc(doc(fs, 'user_game_stats/bob'), { createdAt: Timestamp.now() });
        await setDoc(doc(fs, 'user_game_stats/bob/games/carrom'), { totalGames: 3 });
        await setDoc(doc(fs, 'user_game_stats/bob/carrom_history/cm1'), { myScore: 9 });
        await setDoc(doc(fs, 'leaderboards/carrom/allTime/bob'), { odZ: 'bob', score: 9 });
        await setDoc(doc(fs, 'leaderboards/carrom/daily/2026-10-4/users/bob'), { odZ: 'bob', score: 9 });
        await setDoc(doc(fs, 'leaderboards/carrom/weekly/2026-W40/users/bob'), { odZ: 'bob', score: 9 });
      });
      const fs = db('bob');
      await assertSucceeds(deleteDoc(doc(fs, 'user_game_stats/bob/games/carrom')));
      await assertSucceeds(deleteDoc(doc(fs, 'user_game_stats/bob/carrom_history/cm1')));
      await assertSucceeds(deleteDoc(doc(fs, 'user_game_stats/bob')));
      await assertSucceeds(deleteDoc(doc(fs, 'leaderboards/carrom/allTime/bob')));
      await assertSucceeds(deleteDoc(doc(fs, 'leaderboards/carrom/daily/2026-10-4/users/bob')));
      await assertSucceeds(deleteDoc(doc(fs, 'leaderboards/carrom/weekly/2026-W40/users/bob')));
      // Deleting a row that does not exist is fine (client guesses period keys).
      await assertSucceeds(deleteDoc(doc(fs, 'leaderboards/carrom/daily/2026-10-3/users/bob')));
    });

    it("cannot delete another user's game stats or leaderboard rows", async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        await setDoc(doc(fs, 'user_game_stats/alice'), { createdAt: Timestamp.now() });
        await setDoc(doc(fs, 'user_game_stats/alice/games/carrom'), { totalGames: 3 });
        await setDoc(doc(fs, 'user_game_stats/alice/carrom_history/cm1'), { myScore: 9 });
        await setDoc(doc(fs, 'leaderboards/carrom/allTime/alice'), { odZ: 'alice', score: 9 });
        await setDoc(doc(fs, 'leaderboards/carrom/daily/2026-10-4/users/alice'), { odZ: 'alice', score: 9 });
      });
      const fs = db('bob');
      await assertFails(deleteDoc(doc(fs, 'user_game_stats/alice')));
      await assertFails(deleteDoc(doc(fs, 'user_game_stats/alice/games/carrom')));
      await assertFails(deleteDoc(doc(fs, 'user_game_stats/alice/carrom_history/cm1')));
      await assertFails(deleteDoc(doc(fs, 'leaderboards/carrom/allTime/alice')));
      await assertFails(deleteDoc(doc(fs, 'leaderboards/carrom/daily/2026-10-4/users/alice')));
    });

    it('owner can delete its queue entries (also expired ones on app start)', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        const past = Timestamp.fromDate(new Date(Date.now() - 3600 * 1000));
        await setDoc(doc(fs, 'ludo_queue/bob'), { uid: 'bob', playerCount: 2, expiresAt: past });
        await setDoc(doc(fs, 'carrom_queue/bob'), { uid: 'bob', expiresAt: past });
        await setDoc(doc(fs, 'carrom_queue/alice'), { uid: 'alice' });
      });
      await assertSucceeds(deleteDoc(doc(db('bob'), 'ludo_queue/bob')));
      await assertSucceeds(deleteDoc(doc(db('bob'), 'carrom_queue/bob')));
      await assertFails(deleteDoc(doc(db('bob'), 'carrom_queue/alice')));
    });

    it('owner releases only its own avatar fingerprints', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        await setDoc(doc(fs, 'avatar_fingerprints/00000000000000b0'), { uid: 'bob', createdAt: Timestamp.now() });
        await setDoc(doc(fs, 'avatar_fingerprints/00000000000000a0'), { uid: 'alice', createdAt: Timestamp.now() });
      });
      await assertSucceeds(deleteDoc(doc(db('bob'), 'avatar_fingerprints/00000000000000b0')));
      await assertFails(deleteDoc(doc(db('bob'), 'avatar_fingerprints/00000000000000a0')));
    });

    it('full client deletion sequence succeeds', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        await setDoc(doc(fs, 'public_profiles/bob'), { uid: 'bob', updatedAt: Timestamp.now() });
        await setDoc(doc(fs, 'users/bob/blocked/carol'), { blockedAt: Timestamp.now() });
        await setDoc(doc(fs, 'users/carol/blockedBy/bob'), { blockedAt: Timestamp.now() });
      });
      const fs = db('bob');
      await assertSucceeds(updateDoc(doc(fs, 'conversations/c1'), markDeleted('bob')));
      await assertSucceeds(deleteDoc(doc(fs, 'users/carol/blockedBy/bob')));
      await assertSucceeds(deleteDoc(doc(fs, 'users/bob/blocked/carol')));
      await assertSucceeds(deleteDoc(doc(fs, 'public_profiles/bob')));
      await assertSucceeds(deleteDoc(doc(fs, 'users/bob')));
    });
  });

  describe('avatar fingerprints', () => {
    const fp = 'a1b2c3d4e5f60718';

    it('a user can claim a free face only for themselves', async () => {
      await assertSucceeds(setDoc(doc(db('alice'), `avatar_fingerprints/${fp}`),
        { uid: 'alice', createdAt: serverTimestamp() }));
      await assertFails(setDoc(doc(db('bob'), 'avatar_fingerprints/0000000000000001'),
        { uid: 'alice', createdAt: serverTimestamp() }));
      await assertFails(setDoc(doc(db('bob'), 'avatar_fingerprints/not-a-fingerprint'),
        { uid: 'bob', createdAt: serverTimestamp() }));
      await assertFails(setDoc(doc(db('bob'), 'avatar_fingerprints/0000000000000002'),
        { uid: 'bob', createdAt: serverTimestamp(), extra: true }));
    });

    it('a taken face cannot be overwritten, listed or deleted by others', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `avatar_fingerprints/${fp}`), { uid: 'alice', createdAt: Timestamp.now() });
      });
      await assertSucceeds(getDoc(doc(db('bob'), `avatar_fingerprints/${fp}`)));
      await assertFails(setDoc(doc(db('bob'), `avatar_fingerprints/${fp}`), { uid: 'bob', createdAt: serverTimestamp() }));
      await assertFails(getDocs(collection(db('bob'), 'avatar_fingerprints')));
      await assertFails(deleteDoc(doc(db('bob'), `avatar_fingerprints/${fp}`)));
      await assertSucceeds(deleteDoc(doc(db('alice'), `avatar_fingerprints/${fp}`)));
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
