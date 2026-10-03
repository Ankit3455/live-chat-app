// One-time migration of conversations to the canonical schema documented in
// lib/models/conversation_model.dart. Dry run by default.
//
//   cd functions && npm install
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//     node scripts/migrate_conversations.js [--apply] [--drop-legacy]
//
// --apply        write changes (otherwise only prints what would change)
// --drop-legacy  also delete legacy summary/typing fields. Only use once no
//                installed app version still reads them.
//
// Random-id conversations are kept as they are; the client finds them by
// participants, so no id migration is needed.

const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const APPLY = process.argv.includes('--apply');
const DROP_LEGACY = process.argv.includes('--drop-legacy');
const LEGACY_FIELDS = [
  'lastMessageText',
  'lastMessageSender',
  'lastMessageTime',
  'lastMessageSenderId',
  'isTyping',
  'unreadCount',
];

function toTimestamp(v) {
  if (v == null) return null;
  if (v instanceof Timestamp) return v;
  if (typeof v === 'number') return Timestamp.fromMillis(v);
  return null;
}

function planUpdate(data) {
  const update = {};
  const last = data.lastMessage;

  if (!last || typeof last !== 'object') {
    const text = typeof last === 'string' ? last : data.lastMessageText;
    const senderId = data.lastMessageSender || data.lastMessageSenderId || '';
    const at = toTimestamp(data.lastMessageAt) || toTimestamp(data.lastMessageTime);
    if (senderId) {
      update.lastMessage = { text: text || '', type: 'text', senderId, at: at || null };
    } else if (typeof last === 'string') {
      update.lastMessage = FieldValue.delete();
    }
  }

  if (!(data.lastMessageAt instanceof Timestamp)) {
    const at = toTimestamp(data.lastMessageAt) || toTimestamp(data.lastMessageTime);
    if (at) update.lastMessageAt = at;
  }

  const pData = data.participantData || {};
  for (const [uid, entry] of Object.entries(pData)) {
    if (!entry || typeof entry !== 'object') continue;
    for (const key of ['lastReadAt', 'clearedBefore']) {
      if (typeof entry[key] === 'number') {
        update[`participantData.${uid}.${key}`] = Timestamp.fromMillis(entry[key]);
      }
    }
  }

  if (DROP_LEGACY) {
    for (const f of LEGACY_FIELDS) {
      if (f in data) update[f] = FieldValue.delete();
    }
  }
  return update;
}

async function main() {
  const snap = await db.collection('conversations').get();
  let changed = 0;
  let empty = 0;
  let batch = db.batch();
  let pending = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    if (!(data.lastMessageSender || data.lastMessageSenderId ||
          (data.lastMessage && data.lastMessage.senderId))) {
      empty++;
    }
    const update = planUpdate(data);
    if (Object.keys(update).length === 0) continue;
    changed++;
    console.log(`${doc.id}: ${Object.keys(update).join(', ')}`);
    if (!APPLY) continue;
    batch.update(doc.ref, update);
    if (++pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (APPLY && pending > 0) await batch.commit();

  console.log(`${snap.size} conversations, ${changed} ${APPLY ? 'updated' : 'would change'}, ` +
    `${empty} without messages (hidden by the client).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
