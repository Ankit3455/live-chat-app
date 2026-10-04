// Firebase helpers for the push worker: ID token verification (WebCrypto)
// and Firestore / Realtime Database REST reads made with the caller's own
// ID token, so the project's security rules decide what the worker may see.

const JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const CLOCK_SKEW_S = 300;
const MIN_JWKS_TTL_MS = 60 * 1000;
const DEFAULT_JWKS_TTL_MS = 60 * 60 * 1000;

// Returned by the read helpers when the rules deny the caller.
export const FORBIDDEN = Symbol('forbidden');

export class HttpError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

// ---------- ID token verification ----------

// Per-isolate cache of Google's signing keys: kid -> CryptoKey.
let jwksCache = { keys: new Map(), expiresAt: 0, fetchedAt: 0 };
let jwksInflight = null;

export function resetJwksCache() {
  jwksCache = { keys: new Map(), expiresAt: 0, fetchedAt: 0 };
  jwksInflight = null;
}

function maxAgeMs(cacheControl) {
  const m = /max-age=(\d+)/i.exec(cacheControl || '');
  if (!m) return DEFAULT_JWKS_TTL_MS;
  return Math.max(Number(m[1]) * 1000, MIN_JWKS_TTL_MS);
}

async function loadJwks() {
  const res = await fetch(JWKS_URL);
  if (!res.ok) throw new HttpError(503, 'jwks-unavailable');
  const body = await res.json();
  const keys = new Map();
  for (const jwk of Array.isArray(body.keys) ? body.keys : []) {
    if (!jwk || jwk.kty !== 'RSA' || typeof jwk.kid !== 'string') continue;
    const key = await crypto.subtle.importKey(
      'jwk',
      { kty: 'RSA', n: jwk.n, e: jwk.e, alg: 'RS256', ext: true },
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify'],
    );
    keys.set(jwk.kid, key);
  }
  const now = Date.now();
  jwksCache = { keys, expiresAt: now + maxAgeMs(res.headers.get('cache-control')), fetchedAt: now };
}

async function signingKey(kid) {
  const now = Date.now();
  const fresh = now < jwksCache.expiresAt;
  if (fresh && jwksCache.keys.has(kid)) return jwksCache.keys.get(kid);
  // Unknown kid while the cache is fresh: refetch at most once a minute.
  if (fresh && now - jwksCache.fetchedAt < MIN_JWKS_TTL_MS) return null;
  if (!jwksInflight) jwksInflight = loadJwks().finally(() => { jwksInflight = null; });
  await jwksInflight;
  return jwksCache.keys.get(kid) || null;
}

function b64urlToBytes(s) {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4);
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function b64urlJson(s) {
  return JSON.parse(new TextDecoder().decode(b64urlToBytes(s)));
}

// Verifies a Firebase Auth ID token and returns the uid.
export async function verifyIdToken(token, projectId) {
  const unauth = () => new HttpError(401, 'unauthenticated');
  if (typeof token !== 'string' || token.length > 4096) throw unauth();
  const parts = token.split('.');
  if (parts.length !== 3) throw unauth();

  let header;
  let payload;
  try {
    header = b64urlJson(parts[0]);
    payload = b64urlJson(parts[1]);
  } catch (_) {
    throw unauth();
  }
  if (!header || header.alg !== 'RS256' || typeof header.kid !== 'string') throw unauth();

  const key = await signingKey(header.kid);
  if (!key) throw unauth();
  let valid = false;
  try {
    valid = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      key,
      b64urlToBytes(parts[2]),
      new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
    );
  } catch (_) {
    valid = false;
  }
  if (!valid) throw unauth();

  const now = Math.floor(Date.now() / 1000);
  const p = payload || {};
  if (p.iss !== `https://securetoken.google.com/${projectId}`) throw unauth();
  if (p.aud !== projectId) throw unauth();
  if (typeof p.exp !== 'number' || p.exp <= now) throw unauth();
  if (typeof p.iat !== 'number' || p.iat > now + CLOCK_SKEW_S) throw unauth();
  if (typeof p.auth_time !== 'number' || p.auth_time > now + CLOCK_SKEW_S) throw unauth();
  if (typeof p.sub !== 'string' || p.sub.length === 0 || p.sub.length > 128) throw unauth();
  return p.sub;
}

// ---------- Firestore REST ----------

export function decodeValue(v) {
  if (!v || typeof v !== 'object') return null;
  if ('nullValue' in v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('referenceValue' in v) return v.referenceValue;
  if ('bytesValue' in v) return v.bytesValue;
  if ('geoPointValue' in v) return { latitude: v.geoPointValue.latitude, longitude: v.geoPointValue.longitude };
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decodeValue);
  if ('mapValue' in v) return decodeFields(v.mapValue.fields);
  return null;
}

export function decodeFields(fields) {
  const out = {};
  for (const [k, val] of Object.entries(fields || {})) out[k] = decodeValue(val);
  return out;
}

function docUrl(projectId, segments) {
  const path = segments.map(encodeURIComponent).join('/');
  return `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}`;
}

// Document data, null when missing, FORBIDDEN when the rules deny the read.
export async function firestoreGet(ctx, segments) {
  const res = await fetch(docUrl(ctx.projectId, segments), {
    headers: { Authorization: `Bearer ${ctx.idToken}` },
  });
  if (res.status === 404) return null;
  if (res.status === 403 || res.status === 401) return FORBIDDEN;
  if (!res.ok) throw new HttpError(502, 'firestore-unavailable');
  const doc = await res.json();
  return { id: segments[segments.length - 1], ...decodeFields(doc.fields) };
}

// First conversation whose participants equal [a, b] (legacy auto-id chats).
export async function firestoreFindByParticipants(ctx, sorted) {
  const url = `https://firestore.googleapis.com/v1/projects/${ctx.projectId}/databases/(default)/documents:runQuery`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${ctx.idToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'conversations' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'participants' },
            op: 'EQUAL',
            value: { arrayValue: { values: sorted.map((s) => ({ stringValue: s })) } },
          },
        },
        limit: 1,
      },
    }),
  });
  if (!res.ok) return null;
  const rows = await res.json();
  const hit = Array.isArray(rows) ? rows.find((r) => r && r.document) : null;
  if (!hit) return null;
  const name = hit.document.name || '';
  return { id: name.slice(name.lastIndexOf('/') + 1), ...decodeFields(hit.document.fields) };
}

// ---------- Realtime Database REST ----------

function rtdbBase(databaseUrl) {
  return String(databaseUrl || '').replace(/\/+$/, '');
}

// Value at path (null when missing), FORBIDDEN when the rules deny the read.
export async function rtdbGet(ctx, segments) {
  const path = segments.map(encodeURIComponent).join('/');
  const res = await fetch(`${rtdbBase(ctx.databaseUrl)}/${path}.json?auth=${encodeURIComponent(ctx.idToken)}`);
  if (res.status === 401 || res.status === 403) return FORBIDDEN;
  if (!res.ok) throw new HttpError(502, 'rtdb-unavailable');
  return res.json();
}

// Multi-path update at the root; each path is checked by the rules.
export async function rtdbUpdate(ctx, updates) {
  const res = await fetch(`${rtdbBase(ctx.databaseUrl)}/.json?auth=${encodeURIComponent(ctx.idToken)}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(updates),
  });
  return res.ok;
}
