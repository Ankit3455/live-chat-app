// Conversation rules shared by the functions. No dependencies, so they can
// be unit-tested without the Firebase SDKs (test/*.test.js).

function participantData(conv, uid) {
  const pd = conv && conv.participantData;
  const me = pd && typeof pd === 'object' ? pd[uid] : null;
  return me && typeof me === 'object' ? me : {};
}

// Same rule as CallConsent.isAllowed in the app (DEST-012).
function callAllowed(conv, uidA, uidB, callType) {
  const key = callType === 'video' ? 'video' : 'audio';
  const enabled = (uid) => {
    const flags = participantData(conv, uid).callEnabled;
    return !!flags && flags[key] === true;
  };
  return enabled(uidA) && enabled(uidB);
}

// Same rule as Conversation.stateFor in the app: 'active' | 'new' | 'deleted'.
function stateFor(conv, uid) {
  const s = conv && conv.statePerUser && conv.statePerUser[uid];
  if (typeof s === 'string' && s) return s;
  const me = participantData(conv, uid);
  return me.status === 'active' || me.hasReplied === true ? 'active' : 'new';
}

// Same rule as Conversation.isMuted: participantData first, legacy map second.
function isMuted(conv, uid) {
  const v = participantData(conv, uid).muted;
  if (typeof v === 'boolean') return v;
  return !!(conv && conv.muted && conv.muted[uid] === true);
}

function isDeletedUser(conv, uid) {
  const deleted = Array.isArray(conv && conv.deletedUsers) ? conv.deletedUsers : [];
  return deleted.includes(uid) || participantData(conv, uid).deleted === true;
}

const TYPE_LABELS = {
  image: 'Photo',
  audio: 'Voice message',
  video: 'Video',
  file: 'Document',
  location: 'Location',
  sticker: 'Sticker',
  gif: 'GIF',
};

function truncate(text, max = 120) {
  return text.length > max ? `${text.substring(0, max - 3)}...` : text;
}

// Push body from the message type. Message text is included only when
// [showText] (OneSignal Identity Verification on, DEST-008).
function pushBody(msg, showText) {
  const type = String(msg.type || 'text');
  const text = String(msg.message || '').trim();
  if (type === 'call') return text || 'Missed call';
  const label = TYPE_LABELS[type];
  if (label) return showText && text && type !== 'audio' ? truncate(`${label}: ${text}`) : label;
  return showText && text ? truncate(text) : 'New message';
}

module.exports = { participantData, callAllowed, stateFor, isMuted, isDeletedUser, pushBody };
