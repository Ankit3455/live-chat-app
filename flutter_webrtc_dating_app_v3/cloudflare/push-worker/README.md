# destined-push (Cloudflare Worker)

Sends Destined's OneSignal push notifications. It replaces the Cloud Functions
in `functions/push.js` (`sendChatPush`, `sendCallPush`, the missed-call push),
which can't run on Firebase's free Spark plan.

The app calls the worker directly with the signed-in user's Firebase ID token.
The worker checks the token, reads Firestore / Realtime Database **with that
same token** (so your security rules decide what it can see), and then asks
OneSignal to deliver the push. The OneSignal REST API key stays on Cloudflare
and never ships in the app.

## Cost

Cloudflare Workers free plan: 100,000 requests a day and 10 ms CPU per
request. One chat message or one call = one request. The worker does very
little CPU work (signature check uses the built-in WebCrypto), so it stays
inside the free limits. No credit card needed.

## Before you start: rotate the OneSignal key

The old OneSignal REST API key leaked (it used to be in the app). Make a new
one first, otherwise anyone holding the old key can still send pushes to your
users:

1. OneSignal dashboard -> your app -> **Settings -> Keys & IDs**.
2. Create a new REST API key (or rotate the existing one) and copy it.
3. Delete / revoke the old key.

You'll paste the new key in step 4 below.

## Deploy (step by step)

You need Node.js 18 or newer (`node --version`).

1. Install the Cloudflare CLI:

   ```sh
   npm i -g wrangler
   ```

2. Log in (opens the browser; create a free Cloudflare account if needed):

   ```sh
   wrangler login
   ```

3. Go to this folder:

   ```sh
   cd flutter_webrtc_dating_app_v3/cloudflare/push-worker
   ```

4. Store the OneSignal REST API key as a secret (paste the NEW key when asked;
   it is encrypted on Cloudflare and never written to a file):

   ```sh
   wrangler secret put ONESIGNAL_REST_API_KEY
   ```

   If Wrangler says the worker doesn't exist yet, answer **yes** to create it.
   Both key styles work: new keys starting with `os_v2_` are sent as
   `Authorization: Key ...` to `api.onesignal.com`, legacy keys as
   `Authorization: Basic ...` to `onesignal.com/api/v1`.

5. Deploy:

   ```sh
   wrangler deploy
   ```

   It prints a URL like `https://destined-push.<your-subdomain>.workers.dev`.

6. Put that URL (no trailing slash) in
   `lib/core/config/push_config.dart`:

   ```dart
   static const String workerUrl = 'https://destined-push.<your-subdomain>.workers.dev';
   ```

   Rebuild the app. While `workerUrl` is empty the app skips the worker (and
   tries the old Cloud Functions, which only work on the Blaze plan).

Settings in `wrangler.toml` (`[vars]`):

| Name | Meaning |
| --- | --- |
| `FIREBASE_PROJECT_ID` | `availchatproject` |
| `FIREBASE_DATABASE_URL` | Realtime Database URL |
| `ONESIGNAL_APP_ID` | Public OneSignal app id |
| `SHOW_MESSAGE_TEXT` | `"true"` puts the message text in the push. Keep `"false"` until OneSignal Identity Verification is on (DEST-008); pushes then say "New message", "Photo", ... |

After changing `wrangler.toml`, run `wrangler deploy` again. To watch live
logs: `wrangler tail`.

## Endpoints

Both: `POST`, `Content-Type: application/json`, body at most 4 KB,
`Authorization: Bearer <Firebase ID token>`.

| Endpoint | Body | Sends |
| --- | --- | --- |
| `/chat-push` | `{"conversationId": "...", "messageId": "..."}` | New-message push, or a missed-call push when the message is a `call` message |
| `/call-push` | `{"receiverId": "...", "callId": "..."}` | Incoming-call push (audio/video channel, `ttl` 60, `ios_sound` `incoming_call.caf`) |

Responses: `200 {"ok":true,"status":"sent"}` (other statuses such as
`muted`, `blocked`, `duplicate`, `stale`, `disabled` mean "nothing sent, on
purpose"). `200 {"ok":false,"status":"no-subscribers","reason":"..."}` means
OneSignal accepted the request but had no subscribed device for the receiver
(e.g. "All included players are not subscribed", `invalid_aliases`): the
receiver never logged in on a device with push allowed, or opted out. Or an
error: `400` bad input, `401` bad/expired token, `403` not
allowed, `404` unknown path, `405` not POST, `412` call no longer ringing,
`413` body too big, `415` not JSON, `429` too many requests, `502` OneSignal
or Firebase failed.

### Checks

Token: RS256 signature against Google's public keys (cached per
`Cache-Control`), `iss` = `https://securetoken.google.com/<project>`, `aud` =
project, not expired, `iat` / `auth_time` not in the future, `sub` (uid) set.

Chat push:
- the message exists and its `senderId` is the caller; the receiver is the
  other participant; deleted messages and declined calls are skipped;
- message must be at most 10 minutes old (replays of old messages do nothing);
- skipped when the receiver deleted their account, muted the chat, or either
  user blocked the other;
- channel `onesignal_new_chat_channel` (silent, low importance; lower
  priority, iOS passive) when the receiver hasn't replied yet;
  `onesignal_chat_channel` (high, heads-up) otherwise. The app creates both
  channels.

Call push:
- `callId` starts with `<caller uid>_`, receiver isn't the caller;
- the ringing inbox entry `incoming_calls/<receiver>/<callId>` was written by
  the caller (see "Differences" below), and `rooms/<callId>` names the caller
  and receiver and is still ringing; at most 90 s old;
- not blocked, the conversation exists, the receiver's account isn't deleted,
  and both users enabled that call type. Otherwise the worker removes the
  inbox entry, marks the room ended and returns `403`.

Rate limit: 60 chat pushes and 10 call pushes per user per minute, plus a
"sent already" guard per message / call. Both are kept in worker memory, so
they are **per isolate** (Cloudflare runs many copies): best effort only.

### Differences from push.js

The worker only sees what the caller may read under the current rules:

- **Receiver's notification switches** (`users/<receiver>.notificationSettings`)
  are owner-only, so "push disabled" / "message notifications off" can't be
  checked. The receiver's device still has to be subscribed in OneSignal.
- **Incoming call inbox** (`incoming_calls/<receiver>/...`) is receiver-only.
  The worker then relies on `rooms/<callId>` (state must be `ringing`) and
  tells audio from video by whether the caller's WebRTC offer sends video. To
  check the inbox entry exactly like push.js, add this rule under
  `incoming_calls/$uid/$callId` in `database.rules.json`:
  `".read": "auth != null && data.child('callerId').val() === auth.uid"`.
- **Blocks**: reads the caller's own `blocked/<other>` and the
  `blockedBy/<other>` mirror (written by the blocker); the rules also stop
  blocked users from writing messages.
- **Once-only delivery**: push.js used a server-only `push_receipts`
  collection. The worker's duplicate guard is in memory (per isolate) plus
  the 10-minute message age limit.
- **No Firestore trigger**: `onChatMessageCreated` pushed every new message
  even if the app never asked. Now only messages the app reports via
  `OneSignalSender.sendChatNotification` get a push.
- Caller name comes from `public_profiles/<uid>`, then the caller's own
  `users/<uid>` (`username`, then `name`).

## Test

Offline unit tests (no network, fetch is mocked):

```sh
node --test
```

Against the deployed worker with curl. Get an ID token from a debug build,
e.g. temporarily `debugPrint(await FirebaseAuth.instance.currentUser!.getIdToken());`
(never commit or share it; it expires after an hour):

```sh
URL=https://destined-push.<your-subdomain>.workers.dev
TOKEN=<id token>

# expect 401
curl -i -X POST "$URL/chat-push" -H 'Content-Type: application/json' \
  -d '{"conversationId":"x","messageId":"y"}'

# a message you just sent
curl -i -X POST "$URL/chat-push" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"conversationId":"<conversationId>","messageId":"<messageId>"}'
```
