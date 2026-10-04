// Per-isolate state (best effort). Cloudflare runs many isolates and may
// recycle them at any time, so these limits and the duplicate guard only hold
// within one isolate. They stop accidental loops and casual abuse, not a
// determined attacker.

import { HttpError } from './firebase.js';

const WINDOW_MS = 60 * 1000;
const DEDUPE_TTL_MS = 10 * 60 * 1000;
const MAP_LIMIT = 5000;

const rateBuckets = new Map(); // `${name}:${uid}` -> {start, count}
const sentKeys = new Map(); // dedupe key -> expiresAt

function prune(map, isExpired) {
  if (map.size < MAP_LIMIT) return;
  for (const [k, v] of map) if (isExpired(v)) map.delete(k);
  if (map.size >= MAP_LIMIT) map.clear();
}

// Fixed one-minute window per uid and bucket name; throws 429 when exceeded.
export function rateLimit(uid, name, max) {
  const now = Date.now();
  prune(rateBuckets, (b) => now - b.start >= WINDOW_MS);
  const key = `${name}:${uid}`;
  const b = rateBuckets.get(key);
  if (!b || now - b.start >= WINDOW_MS) {
    rateBuckets.set(key, { start: now, count: 1 });
    return;
  }
  if (b.count >= max) throw new HttpError(429, 'resource-exhausted');
  b.count++;
}

// False when [key] was already sent recently from this isolate.
export function claimOnce(key) {
  const now = Date.now();
  prune(sentKeys, (exp) => exp <= now);
  const exp = sentKeys.get(key);
  if (exp && exp > now) return false;
  sentKeys.set(key, now + DEDUPE_TTL_MS);
  return true;
}

export function releaseClaim(key) {
  sentKeys.delete(key);
}

export function resetState() {
  rateBuckets.clear();
  sentKeys.clear();
}
