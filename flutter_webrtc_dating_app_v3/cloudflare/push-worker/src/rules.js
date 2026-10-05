// Conversation rules, copied from functions/conversation_rules.js so the
// worker behaves exactly like the old Cloud Functions. Keep in sync.

export function participantData(conv, uid) {
  const pd = conv && conv.participantData;
  const me = pd && typeof pd === 'object' ? pd[uid] : null;
  return me && typeof me === 'object' ? me : {};
}

export function callAllowed(conv, uidA, uidB, callType) {
  const key = callType === 'video' ? 'video' : 'audio';
  const enabled = (uid) => {
    const flags = participantData(conv, uid).callEnabled;
    return !!flags && flags[key] === true;
  };
  return enabled(uidA) && enabled(uidB);
}

// 'active' | 'new' | 'deleted'
export function stateFor(conv, uid) {
  const s = conv && conv.statePerUser && conv.statePerUser[uid];
  if (typeof s === 'string' && s) return s;
  const me = participantData(conv, uid);
  return me.status === 'active' || me.hasReplied === true ? 'active' : 'new';
}

export function isMuted(conv, uid) {
  const v = participantData(conv, uid).muted;
  if (typeof v === 'boolean') return v;
  return !!(conv && conv.muted && conv.muted[uid] === true);
}

export function isDeletedUser(conv, uid) {
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

// Built from metadata, never from the message text, so a crafted 'game'
// message can't get past SHOW_MESSAGE_TEXT.
const GAME_TITLES = {
  date: 'Build Our Date',
  rate: 'Rate It',
  flags: 'Red Flag, Green Flag',
  telepathy: 'Telepathy',
  chess: 'Chess',
  tennis: 'Tennis Duel',
  thumb: 'Thumb War',
};

function gamePushBody(meta) {
  const title = meta && typeof meta === 'object' ? GAME_TITLES[meta.game] : undefined;
  if (!title) return 'Game';
  return meta.stage === 'result' ? `${title}: results are in` : `Let's play ${title}!`;
}

function truncate(text, max = 120) {
  return text.length > max ? `${text.substring(0, max - 3)}...` : text;
}

// Message text is included only when [showText] (OneSignal Identity
// Verification on, DEST-008); otherwise a type label.
export function pushBody(msg, showText) {
  const type = String(msg.type || 'text');
  const text = String(msg.message || '').trim();
  if (type === 'call') return text || 'Missed call';
  if (type === 'game') return gamePushBody(msg.metadata);
  const label = TYPE_LABELS[type];
  if (label) return showText && text && type !== 'audio' ? truncate(`${label}: ${text}`) : label;
  return showText && text ? truncate(text) : 'New message';
}

// Audio calls still offer to receive video, so the offer always has an
// m=video section; a video call also sends on it.
export function offerSendsVideo(sdp) {
  if (typeof sdp !== 'string') return false;
  const sections = sdp.split(/\r?\nm=/);
  for (let i = 1; i < sections.length; i++) {
    const s = sections[i];
    if (!s.startsWith('video')) continue;
    if (/\r?\na=(sendrecv|sendonly)\b/.test(s)) return true;
    if (!/\r?\na=(recvonly|inactive)\b/.test(s)) return true; // sendrecv is the default
  }
  return false;
}
