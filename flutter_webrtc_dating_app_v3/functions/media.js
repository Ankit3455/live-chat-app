// Chat and profile media on Cloudinary / Firebase Storage (DEST-046, DEST-013).
//
//  onChatMessageDeleted  always exported. When a message becomes isDeleted,
//                        its Storage file is deleted and its Cloudinary asset
//                        is destroyed (or queued in media_cleanup until the
//                        Admin API is configured).
//  processMediaCleanup   CLOUDINARY_ENABLED only: drains media_cleanup
//                        (deleted messages and deleted accounts).
//  signCloudinaryUpload  CLOUDINARY_ENABLED only: signed upload parameters
//                        with the folder and public_id pinned by the server.
//
// Enabling (O-7): set CLOUDINARY_ENABLED=true and CLOUDINARY_API_KEY in
// functions/.env and `firebase functions:secrets:set CLOUDINARY_API_SECRET`.

const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

const config = require('./config');
const { CLOUDINARY_HOST, storagePath, parseCloudinaryUrl, cloudinarySignature } = require('./media_utils');
const { db, FieldValue, requireUid, requireString, rateLimit, isBlockedBetween, isDeletedUser } = require('./common');

const MEDIA_FIELDS = ['mediaUrl', 'thumbnailUrl'];
const MAX_CLEANUP_ATTEMPTS = 5;

const UPLOAD_KINDS = {
  chat_image: { resourceType: 'image', formats: 'jpg,jpeg,png,webp', chat: true },
  chat_voice: { resourceType: 'video', formats: 'm4a,aac,mp3,wav,ogg,opus,webm', chat: true },
  profile_image: { resourceType: 'image', formats: 'jpg,jpeg,png,webp', folder: (uid) => `profile_photos/${uid}` },
  voice_intro: { resourceType: 'video', formats: 'm4a,aac,mp3,wav,ogg,opus,webm', folder: (uid) => `voices/${uid}` },
};

// Destroys one Cloudinary asset. Returns true when it is gone.
async function destroyCloudinary(url, apiSecret) {
  const asset = parseCloudinaryUrl(url);
  if (!asset || asset.cloud !== config.CLOUDINARY_CLOUD_NAME) return true; // not ours
  const params = {
    public_id: asset.publicId,
    type: asset.type,
    invalidate: 'true',
    timestamp: String(Math.floor(Date.now() / 1000)),
  };
  const body = new URLSearchParams({
    ...params,
    api_key: config.CLOUDINARY_API_KEY,
    signature: cloudinarySignature(params, apiSecret),
  });
  const response = await fetch(
    `https://api.cloudinary.com/v1_1/${config.CLOUDINARY_CLOUD_NAME}/${asset.resourceType}/destroy`,
    { method: 'POST', body },
  );
  if (!response.ok) {
    console.error(`Cloudinary destroy ${response.status}: ${await response.text()}`);
    return false;
  }
  const result = await response.json().catch(() => ({}));
  return result.result === 'ok' || result.result === 'not found';
}

async function queueCleanup(urls, extra) {
  if (!urls.length) return;
  await db().collection('media_cleanup').add({
    ...extra,
    urls,
    createdAt: FieldValue.serverTimestamp(),
  });
}

// Guards against pointing a message or profile at someone else's file and
// then deleting it: the file must live in this chat (or the sender's voice
// folder) and no other live message or profile may still use it.
async function mayDelete(url, ctx) {
  if (ctx.reason === 'message_deleted') {
    const asset = parseCloudinaryUrl(url);
    const path = asset ? asset.publicId : storagePath(url);
    const owned = !!path && (path.startsWith(`chat_media/${ctx.conversationId}/`)
      || (!!ctx.uid && path.startsWith(`voices/${ctx.uid}/`)));
    if (!owned) return false;
    const uses = await db()
      .collection(`conversations/${ctx.conversationId}/messages`)
      .where('mediaUrl', '==', url)
      .limit(5)
      .get();
    return uses.docs.every((d) => d.id === ctx.messageId || d.get('isDeleted') === true);
  }
  if (ctx.reason === 'account_deleted') {
    for (const field of ['profileImage', 'voiceIntroUrl']) {
      const q = await db().collection('users').where(field, '==', url).limit(2).get();
      if (q.docs.some((d) => d.id !== ctx.uid)) return false;
    }
    return true;
  }
  return false;
}

const apiSecret = config.CLOUDINARY_ENABLED ? config.secret('CLOUDINARY_API_SECRET') : null;

exports.onChatMessageDeleted = onDocumentUpdated(
  {
    document: 'conversations/{conversationId}/messages/{messageId}',
    ...(apiSecret ? { secrets: [apiSecret] } : {}),
  },
  async (event) => {
    const before = event.data && event.data.before.data();
    const after = event.data && event.data.after.data();
    if (!before || !after || before.isDeleted === true || after.isDeleted !== true) return;
    const { conversationId, messageId } = event.params;
    const senderId = String(before.senderId || '');

    const meta = { reason: 'message_deleted', uid: senderId, conversationId, messageId };
    const candidates = MEDIA_FIELDS.map((f) => before[f]).filter((u) => typeof u === 'string' && u);
    const urls = [];
    for (const url of new Set(candidates)) {
      if (await mayDelete(url, meta)) urls.push(url);
    }
    if (!urls.length) return;

    const bucket = admin.storage().bucket();
    const storagePaths = urls.map(storagePath).filter(Boolean);
    await Promise.all(storagePaths.map((p) => bucket.file(p).delete({ ignoreNotFound: true })));

    const cloudinary = urls.filter((u) => u.includes(CLOUDINARY_HOST));
    if (!cloudinary.length) return;
    if (!apiSecret) {
      await queueCleanup(cloudinary, meta);
      return;
    }
    const left = [];
    for (const url of cloudinary) {
      if (!(await destroyCloudinary(url, apiSecret.value()).catch(() => false))) left.push(url);
    }
    await queueCleanup(left, meta);
  },
);

if (apiSecret) {
  exports.processMediaCleanup = onSchedule(
    { schedule: 'every 30 minutes', secrets: [apiSecret], timeoutSeconds: 300 },
    async () => {
      const snap = await db().collection('media_cleanup').orderBy('createdAt').limit(50).get();
      for (const doc of snap.docs) {
        const data = doc.data();
        const urls = Array.isArray(data.urls) ? data.urls.filter((u) => typeof u === 'string') : [];
        const left = [];
        const ctx = { reason: data.reason, uid: data.uid, conversationId: data.conversationId, messageId: data.messageId };
        for (const url of urls) {
          if (!(await mayDelete(url, ctx).catch(() => false))) continue;
          if (!(await destroyCloudinary(url, apiSecret.value()).catch(() => false))) left.push(url);
        }
        if (!left.length) {
          await doc.ref.delete();
          continue;
        }
        const attempts = Number(data.attempts || 0) + 1;
        if (attempts >= MAX_CLEANUP_ATTEMPTS) {
          // Park it for manual review so it no longer blocks the queue.
          await db().collection('media_cleanup_failed').doc(doc.id).set({ ...data, urls: left, attempts });
          await doc.ref.delete();
        } else {
          await doc.ref.update({ urls: left, attempts, createdAt: FieldValue.serverTimestamp() });
        }
      }
    },
  );

  // Signed upload: the client posts `params`, `api_key` and `signature` with
  // the file to `uploadUrl` instead of an unsigned upload_preset.
  exports.signCloudinaryUpload = onCall(config.callable({ secrets: [apiSecret] }), async (request) => {
    const uid = requireUid(request);
    const kind = requireString(request.data, 'kind', 40);
    const spec = UPLOAD_KINDS[kind];
    if (!spec) throw new HttpsError('invalid-argument', 'Unknown upload kind');
    await rateLimit(uid, 'upload_sign', 120, 60 * 60);

    let folder;
    if (spec.chat) {
      const conversationId = requireString(request.data, 'conversationId');
      const conv = (await db().doc(`conversations/${conversationId}`).get()).data();
      const participants = conv && Array.isArray(conv.participants) ? conv.participants : [];
      // A pair conversation may not exist before its first message.
      const pairIds = conversationId.split('_');
      const members = participants.length ? participants : (pairIds.length === 2 ? pairIds : []);
      const other = members.find((p) => p !== uid);
      if (!members.includes(uid) || !other) throw new HttpsError('permission-denied', 'Not a participant');
      if ((conv && isDeletedUser(conv, other)) || (await isBlockedBetween(uid, other))) {
        throw new HttpsError('permission-denied', 'Cannot send to this user');
      }
      folder = `chat_media/${conversationId}`;
    } else {
      folder = spec.folder(uid);
    }

    const params = {
      allowed_formats: spec.formats,
      folder,
      public_id: `${uid}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`,
      timestamp: String(Math.floor(Date.now() / 1000)),
      ...(config.CLOUDINARY_SIGNED_PRESET ? { upload_preset: config.CLOUDINARY_SIGNED_PRESET } : {}),
    };
    return {
      uploadUrl: `https://api.cloudinary.com/v1_1/${config.CLOUDINARY_CLOUD_NAME}/${spec.resourceType}/upload`,
      apiKey: config.CLOUDINARY_API_KEY,
      params,
      signature: cloudinarySignature(params, apiSecret.value()),
    };
  });
}
