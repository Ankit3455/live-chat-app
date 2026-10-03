// Cloud Functions entry point. Each module owns its functions; optional ones
// are exported only when their feature switch in functions/.env is on (see
// config.js and .env.example).
//
// Secrets (Secret Manager):
//   ONESIGNAL_REST_API_KEY   required
//   ONESIGNAL_IDENTITY_KEY   when ONESIGNAL_IDENTITY_VERIFIED=true
//   TURN_SHARED_SECRET       when TURN_ENABLED=true
//   CLOUDINARY_API_SECRET    when CLOUDINARY_ENABLED=true

const admin = require('firebase-admin');

admin.initializeApp();

const moderation = require('./moderation');
const push = require('./push');
const identity = require('./identity');
const media = require('./media');

// WP-5 safety and account deletion, WP-3 public profiles.
exports.deleteAccount = require('./account').deleteAccount;
exports.onReportCreated = moderation.onReportCreated;
exports.onBlockWritten = moderation.onBlockWritten;
exports.mirrorPublicProfile = require('./profile_mirror').mirrorPublicProfile;

// Push.
exports.sendChatPush = push.sendChatPush;
exports.sendCallPush = push.sendCallPush;
exports.onChatMessageCreated = push.onChatMessageCreated;

// Cleanup of calls, queues and push bookkeeping.
exports.scheduledCleanup = require('./cleanup').scheduledCleanup;

// Identity and calls.
exports.revokeSessions = identity.revokeSessions;
if (identity.mintOneSignalJwt) exports.mintOneSignalJwt = identity.mintOneSignalJwt;
if (identity.getTurnCredentials) exports.getTurnCredentials = identity.getTurnCredentials;

// Media.
exports.onChatMessageDeleted = media.onChatMessageDeleted;
if (media.processMediaCleanup) exports.processMediaCleanup = media.processMediaCleanup;
if (media.signCloudinaryUpload) exports.signCloudinaryUpload = media.signCloudinaryUpload;
