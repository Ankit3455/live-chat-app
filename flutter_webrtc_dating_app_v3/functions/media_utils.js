// URL and signing helpers for media. No dependencies (unit-tested in test/).

const crypto = require('crypto');

const STORAGE_HOST = 'firebasestorage.googleapis.com';
const CLOUDINARY_HOST = 'res.cloudinary.com';

// Firebase Storage download URL -> object path, or null.
function storagePath(url) {
  try {
    const u = new URL(url);
    if (u.host !== STORAGE_HOST) return null;
    const m = u.pathname.match(/^\/v0\/b\/[^/]+\/o\/(.+)$/);
    return m ? decodeURIComponent(m[1]) : null;
  } catch (_) {
    return null;
  }
}

// https://res.cloudinary.com/<cloud>/<resource>/<type>/[<transforms>/][v<n>/]<public_id>[.<ext>]
function parseCloudinaryUrl(url) {
  try {
    const u = new URL(url);
    if (u.host !== CLOUDINARY_HOST) return null;
    const parts = u.pathname.split('/').filter(Boolean).map(decodeURIComponent);
    if (parts.length < 4) return null;
    const [cloud, resourceType, type, ...rest] = parts;
    const versionAt = rest.findIndex((p) => /^v\d+$/.test(p));
    const idParts = versionAt >= 0 ? rest.slice(versionAt + 1) : rest;
    if (!idParts.length) return null;
    let publicId = idParts.join('/');
    if (resourceType !== 'raw') publicId = publicId.replace(/\.[^/.]+$/, '');
    return { cloud, resourceType, type, publicId };
  } catch (_) {
    return null;
  }
}

function cloudinarySignature(params, apiSecret) {
  const toSign = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== '')
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join('&');
  return crypto.createHash('sha1').update(toSign + apiSecret).digest('hex');
}

module.exports = { STORAGE_HOST, CLOUDINARY_HOST, storagePath, parseCloudinaryUrl, cloudinarySignature };
