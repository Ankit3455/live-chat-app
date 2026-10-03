// One-time backfill of public_profiles/{uid} from users/{uid} (DEST-002).
// The mirrorPublicProfile trigger keeps them in sync afterwards.
// Dry run by default.
//
//   cd functions && npm install
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//     node scripts/backfill_public_profiles.js [--apply]

const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const { buildPublicProfile } = require('../profile_mirror');

const APPLY = process.argv.includes('--apply');
const PAGE = 300;

async function main() {
  let last = null;
  let total = 0;
  let visible = 0;
  for (;;) {
    let q = db.collection('users').orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    const batch = db.batch();
    for (const doc of snap.docs) {
      const pub = buildPublicProfile(doc.id, doc.data());
      total++;
      if (pub.discoveryEnabled) visible++;
      if (APPLY) batch.set(db.collection('public_profiles').doc(doc.id), pub);
    }
    if (APPLY) await batch.commit();
    last = snap.docs[snap.docs.length - 1];
  }
  console.log(`${APPLY ? 'Wrote' : 'Would write'} ${total} public profiles (${visible} discoverable).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
