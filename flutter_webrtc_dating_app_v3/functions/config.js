// Shared configuration for all functions.
//
// Non-secret switches come from functions/.env (see .env.example); the CLI
// loads it before deploy, so they also decide which functions are exported.
// Secrets live in Secret Manager and are only declared when their feature is
// on, so a missing optional secret never blocks `firebase deploy`.

const { defineSecret, defineString } = require('firebase-functions/params');

const flag = (name) => String(process.env[name] || '').toLowerCase() === 'true';

// Public OneSignal app id (not a secret).
const oneSignalAppId = defineString('ONESIGNAL_APP_ID', {
  default: 'f4489084-4880-4e7f-aa6d-a3b0cfb8beb4',
  description: 'OneSignal app id (public)',
});
const oneSignalRestApiKey = defineSecret('ONESIGNAL_REST_API_KEY');

// Turn on only after clients that send App Check tokens are live (O-6).
const ENFORCE_APP_CHECK = flag('ENFORCE_APP_CHECK');

// OneSignal Identity Verification is on (O-5): pushes may carry message text
// and mintOneSignalJwt is exported (needs ONESIGNAL_IDENTITY_KEY).
const ONESIGNAL_IDENTITY_VERIFIED = flag('ONESIGNAL_IDENTITY_VERIFIED');

// Own TURN server provisioned (O-10): getTurnCredentials is exported
// (needs TURN_URLS and the TURN_SHARED_SECRET secret).
const TURN_ENABLED = flag('TURN_ENABLED');
const TURN_URLS = String(process.env.TURN_URLS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);
const TURN_TTL_SECONDS = Number(process.env.TURN_TTL_SECONDS || 3600);

// Cloudinary Admin API configured (O-7): signed uploads and media deletion
// (needs CLOUDINARY_API_KEY and the CLOUDINARY_API_SECRET secret).
const CLOUDINARY_ENABLED = flag('CLOUDINARY_ENABLED');
const CLOUDINARY_CLOUD_NAME = process.env.CLOUDINARY_CLOUD_NAME || 'dekipip5j';
const CLOUDINARY_API_KEY = process.env.CLOUDINARY_API_KEY || '';
const CLOUDINARY_SIGNED_PRESET = process.env.CLOUDINARY_SIGNED_PRESET || '';

const secrets = {};
function secret(name) {
  if (!secrets[name]) secrets[name] = defineSecret(name);
  return secrets[name];
}

// Options for every callable.
function callable(options = {}) {
  return { enforceAppCheck: ENFORCE_APP_CHECK, ...options };
}

module.exports = {
  oneSignalAppId,
  oneSignalRestApiKey,
  ENFORCE_APP_CHECK,
  ONESIGNAL_IDENTITY_VERIFIED,
  TURN_ENABLED,
  TURN_URLS,
  TURN_TTL_SECONDS,
  CLOUDINARY_ENABLED,
  CLOUDINARY_CLOUD_NAME,
  CLOUDINARY_API_KEY,
  CLOUDINARY_SIGNED_PRESET,
  secret,
  callable,
};
