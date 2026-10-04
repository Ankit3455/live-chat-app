// Identity and call-infrastructure callables (DEST-111, DEST-008, DEST-050).
//
//  revokeSessions      always exported; signs out every other device.
//  mintOneSignalJwt    only when ONESIGNAL_IDENTITY_VERIFIED=true (O-5);
//                      secret ONESIGNAL_IDENTITY_KEY = the ES256 private key
//                      (PEM) from OneSignal > Settings > Keys & IDs.
//  getTurnCredentials  only when TURN_ENABLED=true and TURN_URLS is set (O-10);
//                      secret TURN_SHARED_SECRET = coturn static-auth-secret
//                      (use-auth-secret / TURN REST API credentials).

const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const config = require('./config');
const { requireUid, rateLimit } = require('./common');

const JWT_TTL_SECONDS = 60 * 60;
const STUN_SERVERS = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun1.l.google.com:19302' },
];

const base64url = (input) => Buffer.from(input).toString('base64url');

// Revokes refresh tokens for the caller. Other devices are signed out when
// their ID token next refreshes (within an hour); SessionService then logs
// them out of OneSignal. The calling device re-authenticates afterwards.
exports.revokeSessions = onCall(config.callable(), async (request) => {
  const uid = requireUid(request);
  await rateLimit(uid, 'revoke', 5, 60 * 60);
  await admin.auth().revokeRefreshTokens(uid);
  const user = await admin.auth().getUser(uid);
  return { ok: true, revokedAt: Date.parse(user.tokensValidAfterTime || '') || Date.now() };
});

if (config.ONESIGNAL_IDENTITY_VERIFIED) {
  const identityKey = config.secret('ONESIGNAL_IDENTITY_KEY');

  // JWT for OneSignal.login(uid, jwt), bound to the caller's own uid.
  exports.mintOneSignalJwt = onCall(config.callable({ secrets: [identityKey] }), async (request) => {
    const uid = requireUid(request);
    await rateLimit(uid, 'onesignal_jwt', 20, 60 * 60);
    const now = Math.floor(Date.now() / 1000);
    const header = { alg: 'ES256', typ: 'JWT' };
    const payload = {
      iss: config.oneSignalAppId.value(),
      iat: now,
      exp: now + JWT_TTL_SECONDS,
      identity: { external_id: uid },
    };
    const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
    let signature;
    try {
      const key = crypto.createPrivateKey(identityKey.value().replace(/\\n/g, '\n'));
      signature = crypto.sign('sha256', Buffer.from(signingInput), { key, dsaEncoding: 'ieee-p1363' });
    } catch (err) {
      console.error(`mintOneSignalJwt: signing failed: ${err.message}`);
      throw new HttpsError('internal', 'Could not create token');
    }
    return { token: `${signingInput}.${signature.toString('base64url')}`, expiresAt: payload.exp * 1000 };
  });
}

if (config.TURN_ENABLED && config.TURN_URLS.length) {
  const turnSecret = config.secret('TURN_SHARED_SECRET');

  // Short-lived TURN credentials; matches IceServers.resolve() in the app.
  exports.getTurnCredentials = onCall(config.callable({ secrets: [turnSecret] }), async (request) => {
    const uid = requireUid(request);
    await rateLimit(uid, 'turn', 30, 60 * 60);
    const ttl = Math.max(300, Math.min(config.TURN_TTL_SECONDS, 24 * 3600));
    const username = `${Math.floor(Date.now() / 1000) + ttl}:${uid}`;
    const credential = crypto.createHmac('sha1', turnSecret.value()).update(username).digest('base64');
    return {
      iceServers: [...STUN_SERVERS, { urls: config.TURN_URLS, username, credential }],
      ttlSeconds: ttl,
    };
  });
}
