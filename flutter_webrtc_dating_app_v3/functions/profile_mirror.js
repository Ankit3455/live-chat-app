// Public profile mirror (DEST-002). users/{uid} is private; discovery and
// other users read public_profiles/{uid}, which only this trigger writes.
// Keep PUBLIC_FIELDS in sync with lib/models/public_profile.dart.
//
// Wire in index.js (after admin.initializeApp()):
//   exports.mirrorPublicProfile = require('./profile_mirror').mirrorPublicProfile;
// Backfill existing users once: node scripts/backfill_public_profiles.js --apply

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

const MIN_AGE = 18;
const GEOHASH_PRECISION = 5; // ~4.9 km cell; raw coordinates are never published
const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

const PUBLIC_FIELDS = [
  'username', 'profileImage', 'avatar', 'avatarVersion', 'bio', 'interests',
  'zodiacSign', 'sunSign', 'location', 'voiceIntroUrl',
  'voiceIntroDurationSeconds', 'profession', 'habits', 'activityLevel',
  'relationshipGoal', 'relationshipStatus', 'hereFor', 'height', 'bodyType',
  'education', 'lifestyle', 'sleepSchedule', 'foodPreference', 'smokingHabits',
  'drinkingHabits', 'exerciseFrequency', 'pets', 'wantsChildren',
  'partyingFrequency', 'tattoos', 'personalityType', 'politicalViews',
  'religiousViews', 'musicGenres', 'movieGenres', 'tvGenres', 'preferredSigns',
  'personalityPriority', 'believesInAstrology', 'astrologyBeliefLevel',
  'relationshipPriority', 'vibePreference', 'idealDate', 'online', 'lastSeen',
  'hasChildren', 'religion', 'communicationStyle', 'loveLanguage', 'languages',
];

function encodeGeohash(lat, lng, precision = GEOHASH_PRECISION) {
  let latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  let out = '', bit = 0, ch = 0, even = true;
  while (out.length < precision) {
    if (even) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) { ch = (ch << 1) | 1; lngMin = mid; } else { ch <<= 1; lngMax = mid; }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) { ch = (ch << 1) | 1; latMin = mid; } else { ch <<= 1; latMax = mid; }
    }
    even = !even;
    if (++bit === 5) { out += BASE32[ch]; bit = 0; ch = 0; }
  }
  return out;
}

// Same rules as UserModel.parseDob.
function parseDob(v) {
  if (v == null) return null;
  if (typeof v.toDate === 'function') return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === 'number') return new Date(v > 1e12 ? v : v * 1000);
  if (typeof v === 'string') {
    const s = v.trim();
    if (!s) return null;
    const parts = s.split(/[-/.]/);
    if (parts.length === 3 && parts.every((p) => /^\d+$/.test(p))) {
      const [a, b, c] = parts.map(Number);
      const d = a > 31 ? new Date(a, b - 1, c) : new Date(c, b - 1, a);
      return d.getFullYear() > 1900 ? d : null;
    }
    const iso = new Date(s);
    return isNaN(iso.getTime()) ? null : iso;
  }
  return null;
}

function ageOn(dob, now = new Date()) {
  let age = now.getFullYear() - dob.getFullYear();
  const m = now.getMonth() - dob.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < dob.getDate())) age--;
  return age;
}

function geohashFrom(data) {
  if (typeof data.geohash === 'string' && data.geohash.length >= GEOHASH_PRECISION) {
    return data.geohash.substring(0, GEOHASH_PRECISION);
  }
  const lat = data.userLatitude, lng = data.userLongitude;
  if (typeof lat === 'number' && typeof lng === 'number') return encodeGeohash(lat, lng);
  return null;
}

function buildPublicProfile(uid, data) {
  const out = { uid };
  for (const key of PUBLIC_FIELDS) {
    if (data[key] !== undefined && data[key] !== null) out[key] = data[key];
  }
  if (typeof data.gender === 'string' && data.gender.trim()) {
    out.gender = data.gender.trim().toLowerCase();
  }
  const avatarUrl = data.avatarProperties && data.avatarProperties.avatarImageUrl;
  if (typeof avatarUrl === 'string' && avatarUrl) {
    out.avatarProperties = { avatarImageUrl: avatarUrl };
  }
  const dob = parseDob(data.dateOfBirth) || parseDob(data.dob);
  const age = dob ? ageOn(dob) : null;
  if (age != null) out.age = age;
  const hash = geohashFrom(data);
  if (hash) out.geohash = hash;
  // The feed orders by lastSeen; a doc without it would never be listed.
  if (!out.lastSeen) out.lastSeen = data.createdAt || admin.firestore.Timestamp.fromMillis(0);
  if (typeof out.online !== 'boolean') out.online = false;
  out.discoveryEnabled = data.discoveryEnabled === true && age != null && age >= MIN_AGE;
  out.updatedAt = admin.firestore.FieldValue.serverTimestamp();
  return out;
}

// Changes that only touch private fields (tokens, settings, unread counters)
// do not rewrite the public doc.
function publicChanged(before, after) {
  if (!before) return true;
  const keys = [...PUBLIC_FIELDS, 'gender', 'avatarProperties', 'dateOfBirth', 'dob',
    'geohash', 'userLatitude', 'userLongitude', 'discoveryEnabled'];
  return keys.some((k) => JSON.stringify(before[k]) !== JSON.stringify(after[k]));
}

exports.mirrorPublicProfile = onDocumentWritten('users/{uid}', async (event) => {
  const uid = event.params.uid;
  const ref = admin.firestore().collection('public_profiles').doc(uid);
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) {
    await ref.delete();
    return;
  }
  const before = event.data.before.exists ? event.data.before.data() : null;
  if (!publicChanged(before, after)) return;
  // set without merge so a field removed from users disappears here too.
  await ref.set(buildPublicProfile(uid, after));
});

// Used by scripts/backfill_public_profiles.js.
exports.buildPublicProfile = buildPublicProfile;
