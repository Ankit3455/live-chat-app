# Destined: Fix Plan

Companion to `AUDIT.md` (issue IDs DEST-001 … DEST-137). App paths are relative to `flutter_webrtc_dating_app_v3/`.

## Conventions
- **WP** means a small, reviewable work package, meant to be one PR. Each WP lists its exact file set. WPs in the same phase touch disjoint files wherever possible so they can be built in parallel. Where two WPs must touch the same file, the dependency is stated and the later WP rebases on the earlier one.
- **[OWNER]** means console or manual work the repo owner must do (keys, console settings, deploys, store setup). Code cannot do it.
- **[DECISION]** means the work is blocked on a product answer. The question is in AUDIT.md section 5. A safe default is given so work can start.
- **Validation:** the build cannot run in this audit environment (pub.dev is blocked). Each WP therefore lists (a) **static checks**: grep, `dart analyze`/`flutter analyze` and `flutter test` once the toolchain is available, and Firebase emulator rules tests; and (b) **manual device tests** on a real Android device and an iOS device, with 2 accounts where needed.
- Branching: use one `fix/WP-n-<slug>` branch per WP, with the PR base set to the default branch, or to the parent WP's branch when there is a dependency.

## Parallel lanes at a glance
| Phase | WPs that can run in parallel | Must wait for |
|---|---|---|
| 1 | WP-1, WP-2, WP-3, WP-4, WP-5, WP-6, WP-8 | WP-7 waits for WP-5 (API only) |
| 2 | WP-9, WP-12, WP-16, WP-17, WP-19, WP-20 | WP-10 needs WP-9. WP-11 needs WP-4 and WP-9. WP-13 needs WP-7 and WP-12. WP-14 needs WP-12. WP-15 needs WP-5 and WP-9. WP-18 needs WP-3. WP-21 needs WP-20. |
| 3 | WP-22, WP-23 | WP-24 and WP-25 run last (cross-cutting) |
| 4 | WP-26, WP-27 | WP-27 runs after the feature WPs |
| 5 | WP-28 | WP-19, WP-20 |
| 6 | WP-29 (lint part can start in Phase 1) | — |

## Owner / console checklist (all [OWNER] items in one place)
| # | Action | Issues | When |
|---|---|---|---|
| O-1 | Rotate the OneSignal REST API key in the OneSignal dashboard. Run `firebase functions:secrets:set ONESIGNAL_REST_API_KEY`, redeploy the functions, and revoke the old key. Optionally rewrite git history with `git filter-repo` and force-push all branches. | DEST-007 | Day 0 |
| O-2 | Export the current Firestore, RTDB and Storage rules from the console and send them to the team. If they are test mode, deploy WP-1 v1 rules immediately. | DEST-001 | Day 0 |
| O-3 | Confirm the project is on the **Blaze plan**. Functions with secrets, outbound calls to OneSignal and Cloudinary, scheduled functions and TTL all require it. | DEST-011/015/022/051 | Phase 1 |
| O-4 | Deploy rules and indexes: `firebase deploy --only firestore:rules,firestore:indexes,database,storage`. | DEST-001/059 | After WP-1 and WP-23 |
| O-5 | Turn on OneSignal **Identity Verification**, but only after the WP-15 JWT function and the WP-4 client change are live. | DEST-008 | Phase 2 |
| O-6 | Turn on Firebase **App Check** (Play Integrity, App Attest/DeviceCheck), first in monitor mode and then enforced. Restrict API keys in the GCP console by platform and API. Turn on Auth abuse protection (reCAPTCHA Enterprise / SMS region policy), set the password policy to 8+ characters, and enable email-enumeration protection. | DEST-051/112/052 | Phase 1–2 |
| O-7 | Cloudinary: disable or restrict the unsigned presets (allowed formats, max size, no public_id override), switch chat media to authenticated delivery, and store the API secret in Secret Manager. | DEST-013/046 | Phase 2 |
| O-8 | Android: choose the final applicationId (not `com.example.*`), create an upload keystore and a gitignored `android/key.properties`, register debug and release SHA-1/256 in Firebase, and re-download `google-services.json`. | DEST-054/075 | Phase 1 |
| O-9 | iOS: run `flutterfire configure` (adds GoogleService-Info.plist and the reversed client id), upload the APNs key to OneSignal and Firebase, and set the bundle id. | DEST-015 | Phase 1 |
| O-10 | Provision TURN (coturn or a paid provider) and give the secret to the WP-15 credential function. | DEST-050 | Phase 2 |
| O-11 | Publish the Privacy Policy, Terms and Support URLs and a **web account-deletion URL** (Play requirement). Set the store age rating to 17+/18+. | DEST-011/034/010 | Before release |
| O-12 | Configure a Firestore TTL policy on `ludo_queue.expiresAt` and `carrom_queue.expiresAt` (and on call logs if desired). | DEST-087 | Phase 2 |
| O-13 | Set up separate dev and prod Firebase projects for flavors. | DEST-132 | Phase 3 |

---

# Phase 1: Critical Security & Crash

## WP-1: Security rules & indexes v1 (repo-tracked)
- **Issues:** DEST-001 (v1), DEST-004 (interim), DEST-047 (rule), DEST-048 (rule), DEST-059, DEST-113 (rule part)
- **Files (new/changed):** `firestore.rules` (new), `database.rules.json` (new), `storage.rules` (new), `firestore.indexes.json` (new), `firebase.json`, `test/rules/` (new, emulator tests; owned by this WP)
- **Depends on:** none. v1 must stay **compatible with the current client**. WP-23 tightens it after the client write patterns are fixed.
- **[OWNER]:** O-2, O-4.
- **Root cause:** the app has no server layer, and authorization was never written as rules kept in git.
- **Solution:**
  - Firestore v1:
    - `users/{uid}`: signed-in read (temporary until WP-3); write only by the owner, with a deny-list of server-owned fields.
    - `conversations/{id}`: read and update only when `request.auth.uid in resource.data.participants`; create only when the creator's uid is in participants.
    - `messages`: create requires `senderId == auth.uid` and `receiverId` in the parent's participants. Updates by the sender are limited to `message, editedAt, isDeleted, mediaUrl`. Updates by the receiver are limited to `status, readAt, deliveredAt`. senderId, receiverId and timestamp are immutable. `message.size() <= 2000`. mediaUrl must match the Cloudinary host regex.
    - Games: matches readable and writable only by uids in `players`. `user_game_stats` and `leaderboards` writable only by the owner, with bounded increments (interim for DEST-004). Queue docs: the owner writes; a delete by another user is allowed only if a match containing both uids exists (or defer to WP-22).
  - RTDB:
    - `incoming_calls/$uid/$callId`: write allowed if `auth.uid === $uid` or `newData.child('callerId').val() === auth.uid`, and the callId begins with the caller's uid. Read only by $uid.
    - `rooms/$id`: read and write only by the callerId and calleeId stored in the room skeleton.
  - Storage: deny by default; owner-only paths for voices and avatars.
  - Indexes: `ludo_queue(playerCount, createdAt)`, `ludo_matches(state, maxPlayers)`, `carrom_queue(createdAt)`, `matches(playerUids array, createdAt)` for WP-28.
- **Risk:** rules that are too strict break live flows (chat send today rewrites the whole participantData map). Mitigation: v1 deliberately allows participant-wide conversation updates. Deploy to the emulator and staging first.
- **Validation:**
  - Static: `firebase emulators:exec "npm test"` with @firebase/rules-unit-testing cases: a non-participant cannot read a conversation; a user cannot create a message with someone else's senderId; the receiver cannot change `message`; a user cannot write `incoming_calls` with a fake callerId; a user cannot write another user's leaderboard. Confirm firebase.json references all 4 files.
  - Device: with 2 accounts, run signup, discovery, chat (text, image, voice), audio and video calls, and a Ludo and a Carrom match end to end. Confirm there are no PERMISSION_DENIED errors in logcat.

## WP-2: Secret hygiene & console hardening
- **Issues:** DEST-007, DEST-112, DEST-051 (App Check console part), DEST-008 (console toggle, after WP-15)
- **Files:** `.gitleaks.toml` (new), `.pre-commit-config.yaml` (new), `README.md` (security section) at the repo root
- **Depends on:** none (O-5 happens after WP-15).
- **[OWNER]:** O-1, O-5, O-6.
- **Root cause:** a key was committed to the client, and there is no secret scanning or key restriction.
- **Solution:** rotate the key; add gitleaks to pre-commit and CI; document key restriction and App Check rollout.
- **Risk:** low. App Check in enforce mode before the clients ship can lock out old builds, so start in monitor mode.
- **Validation:** Static: `gitleaks detect --source .` passes on HEAD, and the old key reports as revoked in the OneSignal dashboard. Device: a chat push still arrives after rotation, and App Check metrics show verified requests.

## WP-3: Discovery & profile data privacy [DECISION]
- **Issues:** DEST-002, DEST-028, DEST-064, DEST-080, DEST-081, DEST-134, DEST-010 (feed 18+ floor), DEST-056 (home_controller part)
- **Files:** `lib/screens/home/home_controller.dart`, `lib/models/user_model.dart`, `lib/bottom_navigation/managers/firestore_manager.dart`, `lib/screens/settings/discovery_settings_screen.dart`, `lib/managers/filter_preferences.dart`, `lib/services/location_service.dart` (new), `functions/profile_mirror.js` (new; one export line in functions/index.js is coordinated with WP-15)
- **Depends on:** WP-1 (rules for `public_profiles`). The HomeController.signOut one-liner delegates to WP-4's SessionService, so merge it after WP-4 or leave a TODO.
- **[DECISION]:** DEST-002 field list and distance granularity; DEST-028 default filters and ordering; DEST-134 language. Default: show age (not DOB), city, and distance in 5 km buckets; order by lastSeen; English only.
- **Root cause:** public and private data share one doc, filters run on the client over an arbitrary 120-doc window, the current user is derived from the feed, DOB is stored in 3 forms, and settings are device-global.
- **Solution:**
  1. `public_profiles/{uid}` holds username, avatar, age, gender, zodiacSign, interests, a coarse geohash (precision 5), online, lastSeen and discoveryEnabled. An `onDocumentWritten(users/{uid})` Function mirrors it. The feed queries public_profiles only.
  2. HomeController subscribes to `users/{me}` separately. The feed query is `where discoveryEnabled==true, where gender in prefs, where birthYear between, geohash range, orderBy lastSeen desc, limit 30` with startAfter pagination via `get()`. Distances are precomputed before sorting. Search is debounced. The age floor is 18.
  3. UserModel: one canonical `dateOfBirth` (Timestamp), an `int? get age`, a tolerant parser for legacy `dob` (no hard cast), no default completion %, and UI fields moved out.
  4. Discovery settings: discoveryEnabled loads from and saves to Firestore; filter prefs are keyed by uid; save uses try/catch/finally; dependent controls are disabled when filters are off; a PopScope prompts "Discard changes?"; copy moves to AppStrings.
  5. LocationService: checks service enabled and permission, deep-links to settings when permanently denied, refreshes on resume throttled by lastLocationUpdate, writes only the geohash publicly, and is never used after await without a mounted check.
- **Risk:** high. This is a data migration, and old clients read `users`. Mitigation: a backfill script/Function for public_profiles; keep reading `users` until the rules flip in WP-23.
- **Validation:**
  - Static: grep that no UI file reads `userLatitude` of another user and that the feed query targets `public_profiles`. A rules test confirms user B cannot read `users/A`. `dart analyze` is clean for these files.
  - Device: user A with discovery OFF still gets the distance filter working. User B no longer sees A's email or coordinates (inspect the network or Firestore debug log). Filters persist per account: log in as a second account on the same device and confirm defaults. Offline save shows an error instead of hanging. Location permission permanently-denied leads to a settings dialog.

## WP-4: Session & auth lifecycle [DECISION: DEST-010 age policy]
- **Issues:** DEST-005, DEST-009, DEST-010, DEST-018 (service part), DEST-030 (splash and signup part), DEST-052, DEST-053 (splash and presence logs), DEST-074, DEST-078, DEST-102, DEST-111, DEST-124, DEST-008 (client JWT login)
- **Files:** `lib/services/auth_service.dart`, `lib/services/session_service.dart` (new), `lib/screens/auth/login_screen.dart`, `lib/screens/auth/signup_screen.dart`, `lib/screens/auth/splash_screen.dart`, `lib/services/notification/onesignal_helper.dart`, `lib/services/notification/onesignal_service.dart`, `lib/services/notification/push_token_service.dart`, `lib/services/presence_service.dart`, `lib/screens/settings/change_password_screen.dart`
- **Depends on:** none to start. The JWT part of DEST-008 needs WP-15's `mintOneSignalJwt`. The delete-on-failure path in DEST-078 is self-contained.
- **[OWNER]:** O-6 (password policy).
- **Root cause:** auth side effects are scattered across screens, there is no first-login branch, typed exceptions are swallowed, and splash ignores profile state.
- **Solution:**
  1. **SessionService** listens to `authStateChanges`:
     - On user: OneSignal.login(uid[, jwt]) and presence start (cached uid; RTDB `.info/connected` with onDisconnect; ignore `inactive`).
     - `signOut()`: remove the FCM token if that stack is kept, OneSignal.logout(), presence offline for the cached uid, Firebase and Google sign-out, `FirebaseFirestore.instance.terminate()` then `clearPersistence()`, clear uid-scoped prefs.
     - AuthService.signOut delegates to it, and every sign-out entry point calls AuthService.signOut.
  2. Google sign-in: if `isNewUser` or the doc is missing, write defaults (uid, email, createdAt, discoveryEnabled:false, signupCompleted:false) and route to DOB capture, then the questionnaire. Otherwise update only online and lastSeen. Return null on cancel.
  3. Signup: DOB lastDate is now minus 18 years with an explicit age check; Form validators; one 8+ character policy shared with change password; no `.trim()` on passwords; `sendEmailVerification()`; discoveryEnabled:false until onboarding completes; username is no longer defaulted to the email prefix; birthLocation is a separate field; birth time is optional. On profile-write failure: retry once, then `user.delete()`.
  4. Splash routing: a `_navigated` guard and one trigger (default: keep the timer, remove the CTA). Route from the users doc: missing goes to profile setup; `!emailVerified` goes to a verify screen; `!signupCompleted` goes to Questionnaire; `!mandatoryCompleted` goes to PostSignup; otherwise Home. Use pushAndRemoveUntil.
  5. AuthService rethrows FirebaseAuthException. The login screen maps codes to friendly text, uses a theme button, hint "Email", a visibility toggle, TextInputAction/onSubmitted and AutofillHints.
  6. Change password "log out all devices": call a revoke Function (WP-15) or remove the option; it also unlinks OneSignal.
  7. Remove or kDebugMode-guard the PII logs in splash and presence.
- **Risk:** medium-high. Routing regressions can lock users out. `clearPersistence` must run only after terminate.
- **Validation:**
  - Static: grep that `OneSignal.login` appears only in session_service, that `_auth.signOut()` appears only in session_service/auth_service, and that `.trim()` is never applied to password controllers. `dart analyze` is clean.
  - Device:
    - A new Google account lands on onboarding and does not appear in discovery until it finishes. An existing Google account keeps its custom username and avatar after re-login. Cancelling the picker shows no error.
    - Sign up as A, receive a push. Log out, sign up as B on the same device: B receives B's pushes and none of A's. A's chats are not visible offline.
    - Kill the app mid-questionnaire, relaunch, and confirm it resumes at the questionnaire.
    - A wrong password shows "Incorrect password".
    - A DOB under 18 is rejected.
    - Turning airplane mode on mid-signup does not leave an orphan account (retry works).

## WP-5: Safety features & account deletion [DECISION]
- **Issues:** DEST-003 (service, screens, server), DEST-011, DEST-034, DEST-017 (Settings tutorial part)
- **Files:** `lib/services/safety_service.dart` (new), `lib/screens/settings/blocked_users_screen.dart` (new), `lib/screens/chat/widgets/report_dialog.dart` (new), `lib/screens/settings/settings_screen.dart`, `functions/account.js` (new), `functions/moderation.js` (new)
- **Depends on:** WP-1 (rules for `users/{uid}/blocked` and `reports`). WP-7, WP-15, WP-12 and WP-3 consume the block list.
- **[DECISION]:** block semantics, report reasons and review flow, hard vs soft delete, v1 Settings tiles and URLs. Defaults: a block hides both sides everywhere; reasons are Harassment / Spam / Fake profile / Underage / Other; reports go to a `reports` collection plus an email notification Function; delete removes the user's own docs and anonymises their messages.
- **[OWNER]:** O-3, O-11.
- **Root cause:** safety and settings features were stubbed out in the UI only.
- **Solution:**
  - SafetyService: `block(uid)` writes `users/{me}/blocked/{uid}` plus a mirrored `blockedBy`; `unblock`; `report(uid, reason, convId, messageIds)` writes to `reports`; a `blockedIds` stream. Success is shown only after the write completes.
  - Blocked Users screen with unblock. ReportDialog with reasons.
  - Settings:
    - Implement Privacy, Terms and Support with url_launcher. Notifications toggles map to `notificationSettings`.
    - Unbuilt tiles become disabled with a "Soon" badge. Developer Options go behind `kDebugMode`.
    - Change Password shows only for the password provider. Add a Discovery entry.
    - The tutorial returns `Navigator.pop(context, 'showTutorial')` to Home (HomeScreen handles it in WP-8).
  - `deleteAccount` callable: requires a recent auth_time; deletes the Auth user, `users`, `public_profiles`, blocked lists and stats; anonymises messages (senderId to "deleted") or deletes them per the decision; removes the user from conversations; destroys Cloudinary assets through the Admin API; clears RTDB `incoming_calls/{uid}` and rooms; deletes the OneSignal user.
- **Risk:** medium. Deletion is irreversible, so test on the emulator and add a confirmation with re-authentication.
- **Validation:**
  - Static: grep that no `'User blocked'` snackbar exists outside the success callback and that the dev section is inside `if (kDebugMode)`. Function unit tests run against the emulator.
  - Device: A blocks B, then B cannot message A, cannot call A, gets no push, and A disappears from B's feed and vice versa. Unblock restores this. A report creates a doc with the reason. Delete Account (after re-auth) leaves the account unable to log in, the profile gone from discovery and the media URLs returning 404. Every Settings tile either works or is visibly disabled. Release builds show no Developer Options.

## WP-6: Platform configuration (iOS / Android)
- **Issues:** DEST-015, DEST-054, DEST-075, DEST-114, DEST-025 (Android channel part)
- **Files:** `ios/Runner/Info.plist`, `ios/Runner/GoogleService-Info.plist` (owner-generated), `ios/Runner/incoming_call.caf` (new sound), `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/google-services.json` (owner), `android/app/src/main/kotlin/com/example/flutter_webrtc_dating_app_v3/MainActivity.kt`, `android/app/src/main/res/raw/incoming_call.*`, `.gitignore`
- **Depends on:** none.
- **[OWNER]:** O-8, O-9.
- **Root cause:** template defaults were never hardened, and the package was renamed without updating the Firebase registration.
- **Solution:**
  - Info.plist: NSCameraUsageDescription, NSMicrophoneUsageDescription, NSPhotoLibraryUsageDescription, NSLocationWhenInUseUsageDescription, UIBackgroundModes (audio, voip, remote-notification) and CFBundleURLTypes (reversed client id).
  - Android: release signingConfig from key.properties; `android:allowBackup="false"` plus dataExtractionRules; remove the duplicate and unused FGS/full-screen permissions (or declare a call FGS); create the `onesignal_audio_call_channel` and `onesignal_video_call_channel` channels with the incoming_call sound (or align IDs with WP-15).
- **Risk:** low. Changing the applicationId creates a new app identity on Play, so decide on it before first release.
- **Validation:**
  - Static: `plutil -lint ios/Runner/Info.plist`; grep the 4 NS keys; `./gradlew :app:signingReport` shows the release key; the manifest shows no duplicate permissions.
  - Device: on iOS, open the camera, mic, gallery and location without a crash and see the purpose strings; Google sign-in works on both iOS and Android. A call push on Android shows on the call channel with sound. A release APK installs with the release signature.

## WP-7: ChatScreen crash fixes & safety hook-up
- **Issues:** DEST-016, DEST-056 (chat_screen parts), DEST-014, DEST-003 (UI hook-up)
- **Files:** `lib/screens/chat/chat_screen.dart`, `lib/screens/chat/widgets/voice_recording_sheet.dart`
- **Depends on:** WP-5 (SafetyService API). Until it lands, hide the Block and Report items.
- **Root cause:** a `late` field holds async data, there is no error state, there are no mounted checks, and the recorder lifecycle is not tied to the widget.
- **Solution:**
  - `String? _conversationId` plus an `_initError` state with a Retry button. Don't build the AppBar streams or body until the id is non-empty.
  - Add `if (!mounted) return;` after every await (lines 1274, 1293, 1373, 1375, 1998, 2060, 2148).
  - Block and Report call SafetyService; after a block, pop to the list. Hide the call buttons and input when blocked.
  - Voice sheet: dispose cancels an active recording; PopScope confirms discard; a `_finishing` guard; the sheet returns its result via `Navigator.pop(result)` and the parent never pops blindly; an openAppSettings button on permission denial.
- **Risk:** medium. chat_screen is a large god file, so keep the diff surgical.
- **Validation:**
  - Static: grep that `late String _conversationId` is gone; `dart analyze` with `use_build_context_synchronously` reports no hits in these files.
  - Device: airplane mode, then open a new chat: you see the error and Retry, not a red screen. Start a voice note, press back, and the mic indicator turns off (iOS orange dot / Android privacy chip). Double-tap send on a voice note sends exactly one message and stays on ChatScreen. Block works end to end (WP-5 tests).

## WP-8: Home crash fixes & onboarding tour [DECISION: DEST-098 skip semantics]
- **Issues:** DEST-017 (drawer and help sheet), DEST-057, DEST-098
- **Files:** `lib/screens/home/home_screen.dart`, `lib/screens/home/widgets/custom_drawer.dart`, `lib/features/onboarding/home_onboarding.dart`, `lib/features/onboarding/tour_prefs.dart`, `lib/screens/home/widgets/custom_bottom_nav.dart`
- **Depends on:** none. The Settings "showTutorial" result comes from WP-5.
- **Root cause:** a duplicated pop, a disposed context, static GlobalKeys, and Skip treated as "show later".
- **Solution:**
  - Remove the extra pop in the help sheet. CustomDrawer takes an `onShowTutorial` callback from HomeScreen. HomeScreen handles the 'showTutorial' result from Settings.
  - Onboarding and bottom-nav GlobalKeys are created in `_HomeScreenState` and passed in.
  - Default decision: Skip means `setHomeTourCompleted(true)`. The tour triggers when `displayedUsers` first becomes non-empty, not after a fixed 2s delay. Tour prefs are keyed by uid. The force flag is set only in the signup completion path.
- **Risk:** low.
- **Validation:**
  - Static: grep finds no `static final GlobalKey` in onboarding or nav, and exactly one `Navigator.pop` in the help-tutorial path.
  - Device: Help, then Watch Tutorial, starts the tour with no black screen. Drawer, then App Tutorial, starts it. Settings, then View Tutorial, returns Home and starts it. Skip, wait more than 1 hour (or move the clock forward), reopen Home: no tour. Run the astrology Review, then return Home with no duplicate-key error in a debug build.

---

# Phase 2: Core Functional

## WP-9: Call signalling core [DECISION: DEST-019, DEST-050, DEST-073]
- **Issues:** DEST-019, DEST-020, DEST-022 (client), DEST-023, DEST-026 (service), DEST-048 (client), DEST-049 (client), DEST-050, DEST-071, DEST-072, DEST-073, DEST-012 (service check), DEST-133
- **Files:** `lib/services/call/call_service.dart`, `lib/services/call/webrtc/webrtc_service.dart`, `lib/services/call/webrtc/signaling_service.dart`, `lib/services/call/webrtc/ice_servers.dart`, `lib/models/call_model.dart`
- **Depends on:** WP-1 v1 rules (room and inbox paths). TURN credentials come from WP-15 (falls back to the static config until then).
- **[OWNER]:** O-10.
- **Root cause:** one implicit global "current call" with no state machine, wrong signalling order, no cleanup ownership, and no connection-state handling.
- **Solution:**
  1. `enum CallPhase {idle, outgoingRinging, incomingRinging, connecting, active, ended}` plus `bool get isInCall`. Every operation is scoped by callId.
  2. startCall(otherUser): validate consent (both `callEnabled` flags, not blocked); random UUID callId; getUserMedia (with a permission pre-check); room skeleton with callerId and calleeId; offer; **then** the inbox entry with Firestore-sourced names and avatars; **then** the push (not awaited for the UI). Start a 45s no-answer timer that sets 'missed', removes the inbox entry and writes a call-log event.
  3. answerCall: permission pre-check; wait on `rooms/{id}/offer` onValue with a 15s timeout; try/catch, and on failure dispose, remove the inbox entry and set `state='failed'`.
  4. `rejectCall(call)` sets `rooms/{call.id}/state='rejected'` and removes the inbox entry. It never touches the active call. When busy, incoming calls are auto-marked 'busy' (default decision).
  5. endCall sets state 'ended', removes the inbox entry, calls `onDisconnect` on room state, and deletes the room after 5s (a server sweep is in WP-15).
  6. Handle onConnectionState: on disconnected show "Reconnecting" and try an ICE restart, and end after 15s if it fails.
  7. The duration ticker starts when the connection reaches connected.
  8. dispose() nulls the renderer references.
  9. Missed and declined calls write a `type:'call'` message (status, duration) to the conversation (default decision).
  10. ICE servers come from config or a Function. `iceTransportPolicy:'relay'` applies when the conversation is not mutual (per the DEST-050 decision).
- **Risk:** high. Calls are timing-sensitive, so test on real networks (Wi-Fi to LTE).
- **Validation:**
  - Static: grep that startCall writes `incoming_calls` after `writeOffer` and that `rejectCall` has no `endCall()` call. `dart analyze` is clean.
  - Device (2 phones):
    - Answer immediately after ringing starts and the call connects (no "Offer not found").
    - Callee declines: the caller sees "Declined" within 2s.
    - No answer: after 45s the caller sees "No answer" and the callee's chat shows a missed call.
    - During an active A–B call, C calls A: the A–B call continues and C sees busy.
    - Kill the callee app mid-call: the caller ends within about 15s.
    - The RTDB console shows the room removed after hang-up.
    - Duration starts at 00:00 when the call connects.

## WP-10: Call screens
- **Issues:** DEST-021, DEST-025 (ringtone), DEST-026 (UI), DEST-070, DEST-093, DEST-056 (video_call part)
- **Files:** `lib/screens/calls/audio_call_screen.dart`, `lib/screens/calls/video_call_screen.dart`, `lib/screens/calls/incoming_call_screen.dart`
- **Depends on:** WP-9.
- **Root cause:** the call lifecycle is tied to buttons instead of the route, subscriptions are untracked, the ringtone call is commented out, and there is no cancel listener.
- **Solution:**
  - PopScope(canPop:false) with an "End call?" confirm, plus endCall in dispose if the call is still active.
  - WakelockPlus enable and disable.
  - Store and cancel the local and remote subscriptions in AudioCallScreen.
  - The name comes from direction (isOutgoing ? receiverName : callerName), treating '' as missing. Show the avatar.
  - Incoming screen: `_audioPlayer.play(AssetSource('sounds/incoming_call.mp3'))` on loop; listen to room state and inbox removal and pop with "Call cancelled"; a `_handled` flag with a spinner; PopScope where back means reject.
  - Video screen: a 1s timer for duration and a mounted check after renderer init.
- **Risk:** low-medium.
- **Validation:**
  - Static: grep finds `PopScope` in all 3 screens and the ringtone `.play(` uncommented, and the AudioCallScreen subscriptions are cancelled in dispose.
  - Device: back during a call shows the confirm, and confirming ends both sides. The ringtone plays. The caller cancels and the callee screen closes within 2s. Double-tap Accept answers once. Names and avatars are correct on both ends. The screen doesn't sleep during a call. 10 consecutive audio calls show no memory growth (DevTools).

## WP-11: App bootstrap & global listeners [DECISION: DEST-097]
- **Issues:** DEST-018 (start presence), DEST-024, DEST-027, DEST-058, DEST-097, DEST-053 (main.dart:820), DEST-066 (foreground suppression)
- **Files:** `lib/main.dart`, `lib/services/notification/notification_channels.dart`, `lib/services/navigation/pending_intent.dart` (new)
- **Depends on:** WP-4 (SessionService), WP-9 (CallPhase, isInCall).
- **Root cause:** the bootstrap order grew organically, there is no notification click routing, the "shown" flag is set too early, and two push stacks coexist.
- **Solution:**
  1. Startup order: `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`, ErrorHandler, Firestore settings (bounded cache of about 100 MB), RTDB persistence, runApp. Init OneSignal without a permission prompt. Ask for permission once after login, in context.
  2. Start SessionService explicitly (which starts presence), not through a lazy Provider. Remove the dead providers here (coordinated with WP-24).
  3. Incoming listener: skip non-ringing entries and those older than 60s; set `_lastShownCallId` only after the push; when busy, delegate to CallService; on resume, re-query ringing entries.
  4. PendingIntent queue consumed after the splash finishes:
     - OneSignal click listener: new_message opens ChatScreen; call opens IncomingCallScreen if still ringing, otherwise shows a missed snackbar.
     - Local notification taps go through the same router.
     - `addForegroundWillDisplayListener` calls preventDefault when the payload conversationId matches the open chat (a route-aware `currentChatId`).
  5. Default for DEST-097: keep OneSignal and remove the firebase_messaging handlers and background handler (token sync removal is in WP-4).
  6. Remove the debugPrint of the User object.
- **Risk:** medium. Cold-start routing races; test both cold and warm starts.
- **Validation:**
  - Static: grep that `FirebaseMessaging.onMessage` is gone, that `Firebase.initializeApp(options:` is present, that settings are assigned before any `FirebaseFirestore.instance.collection` call in main, and that `addClickListener` is present.
  - Device:
    - App killed, tap a chat push: lands in the right chat after splash.
    - App backgrounded, receive a call, open the app within 30s: the incoming screen shows.
    - Cold start while a call is ringing: the incoming screen survives the splash.
    - In chat X, a message from X shows no banner; a message from Y does.
    - First launch asks for notification permission once.
    - Stale ringing entries older than 60s don't ring on launch.

## WP-12: Chat data layer [DECISION: DEST-118]
- **Issues:** DEST-061, DEST-062, DEST-063, DEST-065 (client), DEST-046, DEST-068 (service), DEST-115, DEST-118, DEST-119, DEST-120, DEST-126, DEST-013 (client checks), DEST-053 (unread_manager log)
- **Files:** `lib/services/chat_service.dart`, `lib/managers/unread_manager.dart`, `lib/models/conversation_model.dart` (or the existing conversation model file), `lib/models/chat_message_model.dart`, `lib/services/storage/cloudinary_storage_repo.dart`, `lib/services/media/chat_media_service.dart`
- **Depends on:** none (WP-23 tightens rules after this). Block filtering uses WP-5's stream.
- **Root cause:** whole-map read-modify-writes, random conversation ids, eager creation, duplicated schema, unbounded batches and swallowed errors.
- **Solution:**
  1. Deterministic conversation id `sorted[0]_sorted[1]`. Created lazily inside the first send's transaction.
  2. One private `_writeMessage` for text and media: batch the message plus dotted-path updates `participantData.$rid.unreadCount: increment(1)`, `participantData.$me.hasReplied:true`, `statePerUser.$me:'active'`, and `statePerUser.$rid` only if absent or deleted. Write canonical summary fields only (lastMessage{text,type,senderId,at}). Return the message id for every type.
  3. markMessagesAsRead: chunks of at most 450, log errors, plus `participantData.$me.lastReadAt` (Timestamp). Add a `markDelivered` API.
  4. deleteMessage and editMessage: check senderId; clear media fields on delete; update the summary if the message is the latest; call a server destroy for media (WP-15).
  5. Typing becomes `typingAt.$uid` (Timestamp) with a 5s staleness window.
  6. `deleteForUser` also sets `clearedBefore` (default WhatsApp-style).
  7. UnreadManager reads a shared conversations stream with visibility rules applied (`(x as num?)?.toInt()`).
  8. Cloudinary: 60s timeouts, fix the folder/public_id doubling, MIME and size checks before upload, and fail instead of uploading the original when compression fails.
- **Risk:** medium-high. Schema change: keep legacy read fallbacks and run a one-time migration script for existing conversations (random ids keep working because lookup goes by participants).
- **Validation:**
  - Static: grep that `'participantData': pData` is gone and that `FieldValue.increment` is used. Unit tests with fake_cloud_firestore (WP-29): concurrent sends produce correct counts; deterministic ids; batch chunking at 1000 messages.
  - Device: 2 users send at the same moment and both unread counts are correct. Opening a profile without messaging creates no conversation for the other user. Deleting the last message updates the list preview. Kill the app while typing and the other side's indicator clears within 5s. Airplane mode upload shows an error within 60s.

## WP-13: ChatScreen features
- **Issues:** DEST-035, DEST-067, DEST-069, DEST-109, DEST-116, DEST-117, DEST-012 (UI toggles), DEST-065 (push after media), DEST-068 (lifecycle), DEST-094 (chat_screen), DEST-047 (client host check), DEST-113 (maxLength), DEST-073 (render call events)
- **Files:** `lib/screens/chat/chat_screen.dart`, `lib/screens/chat/widgets/message_bubble.dart`, `lib/screens/chat/widgets/audio_message.dart`, `lib/screens/chat/widgets/image_message.dart`
- **Depends on:** WP-7, WP-12 (and WP-9 for call-event rendering).
- **[DECISION]:** consent toggle UX (DEST-012). Default: separate audio and video toggles in the AppBar menu, with the buttons enabled only when both users have the flag on.
- **Root cause:** the edit UI was never wired up, the hand-rolled live merge is fragile, streams are built in build(), and the reply preview is a stub.
- **Solution:**
  - An `_editing` state with a banner; send calls editMessage.
  - The live listener is restarted with the server clearedBefore after Clear; insert only on `added`, cutoff-filtered and timestamp-sorted; estimated server timestamps.
  - On a send error, restore the text; the push is not awaited.
  - Store a replyTo snapshot and render it; tapping scrolls to the original.
  - `ValueKey(message.id)` and didUpdateWidget in the media widgets.
  - Mute is read via the model. Call buttons are gated on both users' consent.
  - Media sends trigger the push with the returned id.
  - Mark read only while resumed.
  - The 3 streams are created once.
  - Check mediaUrl against the allowed host before rendering.
  - maxLength 2000.
- **Risk:** medium. Overlaps WP-7's file, so rebase on it.
- **Validation:**
  - Static: grep that `stream: FirebaseFirestore.instance` is not inside build methods and that "Original message content" is gone.
  - Device: Edit changes the original bubble and shows "edited" with no duplicate and no push. Clear chat, have the other side read old messages, and nothing reappears. Reply shows the quoted text. Image and voice sends push "Photo" or "Voice message". With the app backgrounded on the chat, the sender doesn't see read ticks until reopened. Scroll and receive messages while a voice note is playing and its progress stays on the right bubble.

## WP-14: Chat list
- **Issues:** DEST-094 (list), DEST-108, DEST-056 (list), DEST-103 (list error state)
- **Files:** `lib/screens/chat/chat_list_screen.dart`
- **Depends on:** WP-12.
- **Solution:**
  - Cache the stream in initState and user lookups in a `Map<String, Future<UserModel?>>` (or use denormalised names).
  - Navigate first, mark read in the background.
  - Add a confirm or Undo snackbar for delete and clear, and labelled SlidableActions.
  - Add a New-tab badge, handle `snap.hasError` with Retry, and show '' as "No messages yet".
- **Risk:** low.
- **Validation:** Static: grep that `getConversations()` is not called inside build. Device: long-press multi-select doesn't flash a spinner; delete asks for confirmation; a slow network tap opens the chat instantly; a permission error shows the error state.

## WP-15: Cloud Functions hardening [DECISION: DEST-013, DEST-012]
- **Issues:** DEST-051, DEST-065 (server), DEST-066, DEST-003 (server block check), DEST-012 (server consent check), DEST-008 (JWT mint), DEST-022/DEST-049 (scheduled cleanup), DEST-013 (signed uploads), DEST-025 (channel ids), DEST-046 (media destroy), DEST-111 (revoke tokens), DEST-050 (TURN credentials)
- **Files:** `functions/index.js`, `functions/push.js` (new), `functions/cleanup.js` (new), `functions/media.js` (new), `functions/identity.js` (new), `functions/package.json`
- **Depends on:** WP-5 (block schema), WP-9 (call states), WP-12 (message schema). Coordinate the export lines in index.js with WP-3 and WP-5.
- **[OWNER]:** O-1, O-3, O-5, O-7, O-10. Deploy with `firebase deploy --only functions`.
- **Root cause:** the functions validate ownership but not abuse, replay, receiver state or media.
- **Solution:**
  - Replace callable chat push with `onDocumentCreated('conversations/{c}/messages/{m}')`. Skip if the receiver muted or blocked the sender. Use a silent channel when the receiver's state is 'new'. Build the body from type. Collapse by conversation. Keep message text only once Identity Verification is on.
  - sendCallPush: `enforceAppCheck:true`, a `pushedAt` marker in a transaction, consent and block checks, a per-uid rate limit (e.g. 10/min), and channel ids matching WP-6.
  - `mintOneSignalJwt` callable.
  - Scheduled every 5 minutes: delete rooms ended or older than 2h, and inbox entries older than 2 minutes.
  - `signCloudinaryUpload` (participant check, folder pinned, size and format limits) and `destroyMedia`.
  - `revokeSessions` (revokeRefreshTokens).
  - `getTurnCredentials` (short-lived).
  - The app id comes from params.
- **Risk:** medium. Moving push to a trigger changes timing; deploy the trigger before removing the client callable (keep the callable as a no-op for one release).
- **Validation:**
  - Static: functions unit tests with firebase-functions-test (replayed messageId sends one push; muted receiver gets no push; non-participant upload signature is refused). ESLint passes.
  - Device: send text, image and voice to a backgrounded receiver and each arrives once with the correct preview. A muted chat sends no push. Replaying the call push via a script is refused. Uploading without a signature fails once the presets are locked (O-7).

## WP-16: Onboarding questionnaire
- **Issues:** DEST-031, DEST-032, DEST-079, DEST-082, DEST-030 (in-flow back), DEST-110 (questionnaire/post-signup/voice), DEST-103 (avatar preview)
- **Files:** `lib/screens/questionnaire/widgets/question_widget.dart`, `lib/screens/questionnaire/questionnaire_screen.dart`, `lib/screens/questionnaire/post_signup_questions_screen.dart`, `lib/screens/questionnaire/profile_completion_screen.dart`, `lib/managers/profile_completion_manager.dart`, `lib/screens/questionnaire/helpers/questionnaire_helper.dart`, `lib/screens/profile/avatar_preview_screen.dart`, `lib/screens/profile/voice_intro_screen.dart`
- **Depends on:** WP-4 (routing contract). The tolerant hereFor read in UserModel is in WP-3.
- **Root cause:** a controller created in build, a generic List type check, no re-entrancy guards, fixed layouts, and a field-name collision.
- **Solution:**
  - QuestionWidget: StatefulWidget-owned controller with didUpdateWidget; `List<String>.from(...)`; keyboardType and maxLength per field.
  - hereFor becomes multiChoice. The location question writes `currentCity`.
  - PostSignup: `onPressed: _isLoading ? null : _nextPage` plus a guard; await completion before navigating; completion includes the mandatory fields; banner prefs keyed by uid; mark signupCompleted and mandatoryCompleted reliably.
  - PopScope in-flow back. `automaticallyImplyLeading:false` on AvatarPreview. Titles and Continue reflect `_generating`/`_error`, and no raw `$e` is shown.
  - Wrap page bodies in a scroll view.
- **Risk:** low-medium.
- **Validation:**
  - Static: grep finds no `TextEditingController(` inside build and no `is List<String>`.
  - Device: type and edit in the middle of the username and bio and the cursor stays put. Saved pets and music show as selected and adding one keeps the others. Double-tap Finish produces one VoiceIntro. Back in the questionnaire goes to the previous question, never to Login. Run on a 5-inch device and at large text scale with no overflow stripes. Birth location survives the questionnaire.

## WP-17: Profile & avatar [DECISION: DEST-076]
- **Issues:** DEST-033, DEST-099, DEST-076, DEST-135, DEST-103 (profile parts), DEST-056 (profile_screen), DEST-053 (dicebear log)
- **Files:** `lib/screens/profile/profile_screen.dart`, `lib/screens/profile/profile_edit_screen.dart`, `lib/services/dicebear_avatar_service.dart`, `lib/services/avatar_mapping.dart`, `lib/widgets/user_avatar.dart`, `lib/services/profile_photo_service.dart` (new)
- **Depends on:** none (questionnaire_helper's props builder is unified in WP-16; agree the shape first).
- **Root cause:** key name mismatch, misplaced features, and seed-only DiceBear params.
- **Solution:**
  - Read `avatarImageUrl`; if empty, regenerate; never write null.
  - Move photo actions into a ProfilePhotoService and call it from My Profile's Change Avatar sheet (Change photo / Reset to avatar / Regenerate), then refresh.
  - Remove the photo card from Edit Profile and group its fields into sections.
  - DiceBear: explicit avataaars params from the answers (default mapping), with one props shape.
  - ProfileScreen: `fromFirestore(doc)`, a mounted check, a missing-doc error state, and a refresh that reassigns the controllers.
- **Risk:** low.
- **Validation:** Static: grep finds no `avatarPngUrl` and no 'coming soon' in profile_screen. Device: Reset to Avatar shows the avatar (not blank). Change Avatar from My Profile updates instantly. Male and female answers produce matching avatar styles. Edit Profile on a 360dp emulator shows no overflow.

## WP-18: Astrology & compatibility [DECISION: DEST-029, DEST-100, DEST-096]
- **Issues:** DEST-029, DEST-077, DEST-100, DEST-096, DEST-110 (astrology intro), DEST-056 (profile_quick_sheet)
- **Files:** `lib/screens/astrology/**`, `lib/core/utils/astrology_view_model.dart`, `lib/core/utils/compatibility_utils.dart`, `lib/core/utils/astrology_utils.dart`, `lib/screens/home/widgets/profile_card.dart`, `lib/screens/home/widgets/profile_quick_sheet.dart`
- **Depends on:** WP-3 (a real currentUser). The removal of the global AstrologyViewModel provider line in main.dart is coordinated with WP-11.
- **Solution:**
  - `CompatibilityService.score(me, other)` (sun-sign table, optionally blended per the decision) and a chip on the card avatar area, hidden when a sign is missing, with the owner's tooltip. The quick sheet uses the same function. Remove matchPercentage reads. Tap opens the quick sheet or profile with a Message CTA (default).
  - The astrology flow becomes one PageView with the reduced question set; steps 2 and 4 merge; Skip exits and saves partial answers; save pops to the caller.
  - The view model is scoped to the flow and preloaded. Save `believesInAstrology` (bool) and `believesInAstrologyLabel` separately.
  - Card animation: one shared controller inside a RepaintBoundary, respecting disableAnimations.
- **Risk:** low-medium.
- **Validation:** Static: grep shows `compatibilityScore(` called from profile_card and no `pushAndRemoveUntil` in review_screen. Device: the chip shows on cards and tapping it shows the tooltip. Log out A and log in B, then the astrology review shows B's answers (empty). Skip mid-flow returns to Profile. Turn on Reduce Motion and the cards stop floating. The DevTools frame chart on a mid-range Android shows no jank on Home.

## WP-19: Ludo correctness [DECISION: DEST-037, DEST-121]
- **Issues:** DEST-036 (Ludo), DEST-037, DEST-038, DEST-039, DEST-040, DEST-086, DEST-087 (Ludo), DEST-088 (Ludo), DEST-089, DEST-090, DEST-092 (Back to Lobby), DEST-110 (board size), DEST-121, DEST-122 (Ludo), DEST-123, DEST-125, DEST-136
- **Files:** `lib/feature/games/ludo/ludo_multiplayer_provider.dart`, `lib/feature/games/ludo/services/ludo_game_service.dart`, `lib/feature/games/ludo/ludo_lobby_screen.dart`, `lib/feature/games/ludo/ludo_wrapper_screen.dart`, `lib/feature/games/ludo/widgets/game_chat_widget.dart`, `lib/feature/games/ludo/widgets/board_widget.dart`, `lib/feature/games/ludo/ludo_player.dart`, `lib/feature/games/ludo/audio.dart`
- **Depends on:** WP-1 (indexes).
- **Root cause:** turns are enforced only by the turn holder, pause is treated as leave, reconnect re-initialises pawns, the client's active colours diverge from the server, and matchmaking does not claim both entries atomically.
- **Solution:**
  - Turn writes in transactions guarded by `turnColor` and `turnSeq`. `turnStartedAt` and `turnSeq` change on every turn, including bonus turns. Any participant may advance the turn after deadline plus 5s grace. Pause the timeout while moving.
  - Pause sets status 'away' with a forfeitDeadline (default 60s). Forfeit only on deadline or explicit Leave. Fix the dialog copy. Add a "Resume match" banner in the lobby.
  - Reconnect changes only the status. pawnSteps is never touched on leave or reconnect.
  - `_activeColors` comes from server `activeColors`. Write only `pawnSteps.<color>`.
  - Legal-move computation for every dice value; reject overshoot.
  - The matchmaking transaction reads and deletes both queue docs. Queue entries carry expiresAt and a heartbeat with an age filter. Stop polling once claimed.
  - Chat: descending order with limit, the stream in initState, auto-scroll, maxLength.
  - Provider: dispose plus a `_disposed` guard; a timer ValueNotifier.
  - Board: stable comparator, opposite colours for 2 players, random first player, render only active colours, size with min(w, h).
  - Audio from callbacks, with a player pool.
  - "Back to Lobby" goes to LudoLobby.
  - Remove the "Win to earn points" line (default) until stats exist.
- **Risk:** high. Multiplayer race conditions need 2–4 device tests.
- **Validation:**
  - Static: grep finds no `pawnSteps[playerColor] = [-1` and a `runTransaction` in turn writes. Unit tests (WP-29) for legal moves and the next-active-colour logic.
  - Device (2 phones, plus 4 for one run): pull the notification shade for 5s and the game continues. Kill the turn holder's app and the other player advances after 35s. A 6 near home doesn't offer an overshoot pawn. Start a search on both phones at the same second and they land in one shared match. Chat with 120 messages shows the latest. Leave mid-roll with no Firestore write afterwards (check the console).

## WP-20: Carrom correctness [DECISION: DEST-006, DEST-045]
- **Issues:** DEST-006, DEST-041, DEST-042, DEST-036 (Carrom), DEST-043, DEST-044, DEST-045, DEST-087 (Carrom), DEST-088 (Carrom), DEST-085, DEST-091, DEST-083, DEST-060, DEST-092 (result screen: chat, leaderboard placeholder, back target), DEST-122 (Carrom)
- **Files:** `lib/feature/games/carrom/carrom_game_screen.dart`, `lib/feature/games/carrom/carrom_lobby_screen.dart`, `lib/feature/games/carrom/carrom_match_screen.dart`, `lib/feature/games/carrom/carrom_result_screen.dart`, `lib/feature/games/carrom/services/carrom_stats_service.dart`, `lib/feature/games/carrom/services/carrom_audio_service.dart`, `assets/games/carrom/audio/*` (new), `pubspec.yaml` (assets section only)
- **Depends on:** WP-1 (indexes, match rules).
- **Root cause:** scoring was never written, the striker has no turn gate, two sync models are mixed, pairing is one-way, a countdown race exists, there is no forfeit, and stats are not idempotent.
- **Solution:**
  - Scoring per the decision (default ICF-lite: white 20 / black 10 / queen 50 with cover, foul = lose turn and return a coin, game to 25 points or clear the board). Serialize queenCoveredBy.
  - `isMyTurn` gate on drag. Baseline-only placement. Shot write in a transaction checking `turn == me`.
  - Snapshot-only sync: apply the final boardState with animation. `moveSeq` dedupe. No local pocketing outside your own turn. `_resultShown` guard.
  - Fixed logical board units scaled through the camera. Bodies added to `world`.
  - Lobby re-checks the queue and listens for a claim. Accept only matches created after searchStart. Order by createdAt. expiresAt.
  - Match screen re-checks status when the countdown ends, adds a timeout and back path, and guards navigation.
  - PopScope forfeit; lifecycle grace; hide reset during play (rematch request after the game).
  - Timer restarts on every turnSeq change.
  - Stats in one transaction guarded by `carrom_history/{matchId}`.
  - Add the audio assets and declare them; remove `assets/icons/` from pubspec.
  - Result screen: remove the placeholder class and import the real leaderboard; Chat opens ChatScreen(opponentUid); the back target is the game list; the result sound plays once and handles draws.
- **Risk:** high. Physics and sync changes, so test on 2 different screen sizes.
- **Validation:**
  - Static: grep shows `scores[shotFrom]` incremented in `_finalizeShot`, no second `class CarromLeaderboardScreen`, and no `assets/icons/` in pubspec. Unit test the scoring function (pocket white, queen with and without cover, foul).
  - Device (a small phone and a large phone): pocketing coins changes the score and reaching 25 ends the game with the correct winner. The waiting player cannot drag the striker. Coin positions match on both screens after 10 shots. Both phones search at the same time and pair. The non-host enters the game together with the host. Back opens the forfeit dialog and the opponent sees a win. The result stats increment exactly once. Sounds play.

## WP-21: Game list & Love Physics [DECISION: DEST-084]
- **Issues:** DEST-092 (game list: Chess, leaderboard import), DEST-084, DEST-137
- **Files:** `lib/feature/games/game_list_screen.dart`, `lib/feature/games/love_physics/love_physics_game.dart`, `lib/feature/games/carrom/common/game_leaderboard_screen.dart`, `lib/feature/games/carrom/common/game_stats_widget.dart`
- **Depends on:** WP-20 (placeholder removal).
- **Solution:** import the real leaderboard; the Chess card is visually disabled with no onTap; stats use a StreamBuilder and handle no-user; Love Physics is fixed and linked (radius-aware win, a single chain body, renamed duplicate class) or deleted per the decision.
- **Risk:** low.
- **Validation:** Device: the leaderboard opens the tabbed screen with a back button; stats update after a Carrom game; Chess does nothing and looks disabled; Love Physics (if kept) can be won.

---

# Phase 3: Architecture & Code Quality

## WP-22: Server-authoritative games [DECISION: DEST-004, DEST-055]
- **Issues:** DEST-004 (full), DEST-055, DEST-121 (stats if approved)
- **Files:** `functions/games.js` (new), `firestore.rules` (games section, coordinated with WP-23), `lib/feature/games/ludo/services/ludo_game_service.dart`, `lib/feature/games/carrom/services/carrom_match_repository.dart` (new; carrom_game_screen call sites are touched minimally after WP-20)
- **Depends on:** WP-19, WP-20, WP-15, WP-1.
- **[OWNER]:** O-3.
- **Solution:**
  - Callables `ludoRoll` (server RNG), `ludoMove` (validate legality and turn) and `carromSubmitShot` (accept the final board with sanity checks). Matchmaking runs in a Function. Stats and leaderboards are computed in `onDocumentUpdated` when the match reaches finished.
  - Rules: clients may write only an intent field on their own turn; stats and leaderboards are Functions-only; match reads are participant-only via `playerUids`.
  - Per the DEST-055 decision: an invite-from-chat flow (`game_invites/{id}`) and block/report in game chat.
- **Risk:** high latency for dice and moves, so measure. Keep animations optimistic.
- **Validation:** Static: a rules test confirms a client can't write `winners` or a leaderboard. Device: normal play still works; editing a match doc from a debug client is denied.

## WP-23: Rules v2 (tightened)
- **Issues:** DEST-001 (final), DEST-002 (users private), DEST-061 (rules side), DEST-003 (block enforcement), DEST-012 (consent mirror)
- **Files:** `firestore.rules`, `database.rules.json`, `storage.rules`, `test/rules/*`
- **Depends on:** WP-3, WP-5, WP-9, WP-12 deployed to all active clients (enforce a minimum app version first).
- **[OWNER]:** O-4.
- **Solution:**
  - `users/{uid}` becomes owner-only read. `public_profiles` is readable by signed-in users and writable by Functions only.
  - Conversation updates use the affectedKeys allow-list: lastMessage, `participantData.<self>`, `statePerUser.<self>`, `typingAt.<self>`, plus an increment-by-1 on the other user's unreadCount.
  - Message create is denied when the receiver has blocked the sender.
  - Inbox writes require a consent mirror node `call_consent/{convId}/{uid}`.
- **Risk:** high. Old clients break, so ship behind a minimum-version check.
- **Validation:** emulator rules suite (positive and negative cases for each path), then a full device regression of WP-1's flows.

## WP-24: Data layer, config & god-widget split
- **Issues:** DEST-127, DEST-129, DEST-132
- **Files:** `lib/repositories/{user,conversation,call,match}_repository.dart` (new), `lib/core/config/app_config.dart` (new), `lib/core/config/storage_config.dart`, `lib/services/database_service.dart` (delete), `lib/main.dart` (provider list), `lib/services/notification/onesignal_service.dart`, `lib/services/call/webrtc/ice_servers.dart`, extracted files from `chat_screen.dart` (ChatController) and `carrom_game_screen.dart` (Flame components into `carrom/components/*.dart`)
- **Depends on:** all of Phase 2 merged (this WP touches files owned there).
- **[OWNER]:** O-13.
- **Solution:** inject Firebase instances through constructors; expose repositories via Provider; extract ChatController and the Carrom components; AppConfig from `--dart-define`/flavors (dev and prod); a single OneSignal id constant; remove the dead providers.
- **Risk:** medium. A refactor with no behaviour change, so rely on the WP-29 tests.
- **Validation:** Static: the `FirebaseFirestore.instance` count in `lib/screens` drops to 0 (grep); `dart analyze` is clean; `flutter test` is green. Device: full smoke test on a dev flavor pointing at the dev project.

## WP-25: Dead code & dependency cleanup [DECISION: DEST-128, DEST-130]
- **Issues:** DEST-128, DEST-130
- **Files:** deletions — commented blocks in `lib/main.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/chat/chat_screen.dart`, `lib/screens/chat/widgets/message_bubble.dart`, `lib/feature/games/carrom/carrom_game_screen.dart`, the Ludo files, `lib/feature/games/ludo/ludo_provider.dart`, `lib/feature/games/ludo/main_screen.dart`, `lib/feature/games/ludo/models/ludo_models.dart`, `lib/screens/home/home_ui.dart`, `lib/screens/home/home_logic.dart`, `lib/screens/auth/astrology_*`, `lib/screens/home/widgets/profile_bubble_grid_item.dart`, `lib/widgets/profile_completion_banner.dart` (if duplicate), unused ChatService methods; `pubspec.yaml` (dependencies)
- **Depends on:** run **last** among the code WPs (after Phases 2, 3 and 4) so no one rebases onto giant deletions mid-flight. It can alternatively run first, on day 1, before any parallel work starts. Choose one and announce it.
- **Solution:** delete the comment blocks and unreachable files; remove dead imports; remove the unused packages (keep wakelock_plus, now used by WP-10); swap Image.network for CachedNetworkImage with memCacheWidth on avatars and cards; bump intl.
- **Risk:** low (deletion), but the diff is large, so review by file list.
- **Validation:** Static: an import-graph script finds no unreachable files; `dart analyze` is clean; `flutter pub deps` shows no unused packages; APK size before vs after is recorded. Device: smoke test of every screen.

---

# Phase 4: UI/UX

## WP-26: Home shell & navigation [DECISION: DEST-101]
- **Issues:** DEST-101, DEST-107
- **Files:** `lib/screens/shell/main_shell.dart` (new), `lib/screens/home/home_screen.dart`, `lib/screens/home/widgets/custom_drawer.dart` (delete or shrink), `lib/screens/home/widgets/custom_bottom_nav.dart`
- **Depends on:** WP-8.
- **Solution:** a MainShell with an IndexedStack (Discover, Chats, Games, Profile), a persistent nav with the real currentIndex and safe-area padding; remove search, the hamburger and the endDrawer; move Help and Sign out to Profile/Settings; remove the bell or turn it into an activity feed.
- **Risk:** medium (navigation regressions).
- **Validation:** Device: switching tabs keeps scroll state; back from any tab goes to Discover and then exits; nothing overlaps the iOS home indicator; no search or hamburger is visible.

## WP-27: Theme, contrast & accessibility
- **Issues:** DEST-104, DEST-105, DEST-106
- **Files:** `lib/core/theme/app_theme.dart`, `lib/core/constants/app_colors.dart`, plus colour-literal and Semantics changes across `lib/screens/**` and `lib/feature/**` (sweeping)
- **Depends on:** all feature WPs in Phases 2–4, to avoid conflicts. Do it as a series of per-folder PRs.
- **Solution:** one palette (add the #7B2CBF family to ColorScheme); replace literals; light tints for text; standard buttons (CustomButton or theme); load Montserrat via GoogleFonts in the theme or declare it; tooltips and Semantics on custom controls; 48dp targets; labels alongside the colour dots.
- **Risk:** low (visual).
- **Validation:** Static: the count of non-core `Color(0x` literals is under 20 (grep); the IconButton count roughly equals the tooltip count. Device: TalkBack/VoiceOver walk through the call screen, chat and nav announce every control; a contrast checker on screenshots shows at least 4.5:1 for body text; large-font mode works.

---

# Phase 5: Performance

## WP-28: Lobby queries & match indexing
- **Issues:** DEST-095 (DEST-093, 094 and 096 are fixed in WP-10, WP-13/14 and WP-18; DEST-028 in WP-3; the DEST-058 cache bound in WP-11)
- **Files:** `lib/feature/games/ludo/ludo_lobby_screen.dart`, `lib/feature/games/carrom/carrom_lobby_screen.dart`, `firestore.indexes.json`
- **Depends on:** WP-19, WP-20, WP-1.
- **Solution:** store `playerUids` on match creation; query `arrayContains uid` with `createdAt > searchStart` and `limit(1)`, or listen to your own queue doc's `matchId`; remove the per-second polling.
- **Risk:** low.
- **Validation:** Static: grep finds no `whereIn: ['ready','started']` scans. Device and console: Firestore usage for one Carrom search drops from about 45 reads × N matches to fewer than 10 reads, with the same pairing behaviour.

Performance acceptance for the whole app (measured after Phases 2–5):
- Cold start to first frame under 2s on a mid-range Android (no network awaits before runApp).
- The Home feed loads at most 30 profile reads per page.
- The chat screen holds 3 listeners per open chat with no re-subscription on typing.
- 10 calls in a row show no heap growth.

---

# Phase 6: Testing & Regression Prevention

## WP-29: Tests, lint, CI
- **Issues:** DEST-131 (plus regression coverage for the High and Critical items above)
- **Files:** `analysis_options.yaml`, `test/widget_test.dart` (replace), `test/unit/**` (new), `test/rules/**` (shared with WP-1/23), `pubspec.yaml` (dev_dependencies: fake_cloud_firestore, mocktail, firebase_auth_mocks), CI config (Rio `rio.yml` or `.github/workflows/ci.yml`), `.githooks/pre-commit`
- **Depends on:** the lint part can land in Phase 1 (warnings first, errors later). The test suites follow each WP.
- **Solution:**
  - Lints: avoid_print, use_build_context_synchronously, unawaited_futures, cancel_subscriptions, close_sinks, empty_catches, prefer_const, deprecated_member_use (withOpacity to withValues).
  - Unit tests:
    - ChatService: field-path writes, deterministic id, read chunking.
    - HomeController: filters, age floor, current user loaded separately.
    - UserModel parsing: legacy dob, List<dynamic>.
    - Ludo rules: legal moves, next active colour, win.
    - Carrom scoring.
    - CallService state machine with a fake signalling layer.
    - SessionService signOut order.
  - Widget tests: QuestionWidget cursor stability; ChatScreen init error state; PostSignup double tap.
  - Rules tests in the emulator. Functions tests.
  - CI runs `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, the rules emulator suite and gitleaks.
- **Risk:** none functionally. pub.dev is blocked in this audit environment, so the suite must run on a developer machine or CI.
- **Validation:** CI green on main. Coverage report: at least 60% on `lib/services/**` and the games rule files. Every High or Critical issue ID is referenced by at least one test or a documented manual test case.

## Manual regression checklist (run on Android and iOS, 2 accounts, before each release)
1. Signup (email) end to end, kill and resume mid-flow, under-18 rejected, email verification enforced.
2. Google signup (new and returning), cancel picker.
3. Discovery: privacy (no PII in other users' docs), filters per account, online status accurate within 1 minute of killing the app.
4. Chat: text, image, voice, edit, delete, reply, clear, mute, block, report, push for each type (foreground, background, killed), tap push opens the chat.
5. Calls: audio and video both directions, decline, no answer, busy, caller cancel, back button, network drop, ringtone, names, missed-call record, push while killed.
6. Ludo: 2- and 4-player, background briefly, kill the turn holder, bonus turns, chat over 100 messages.
7. Carrom: score to 25, turn gating, different screen sizes, forfeit, stats once, leaderboard.
8. Settings: every tile, delete account, logout then login as a different user on the same device (no cross-account pushes or data).
9. Accessibility: TalkBack/VoiceOver on calls, chat and nav; large text.
10. Release build: signed with the release key, no Developer Options, no PII in logcat (`adb logcat | grep -i -E "email|refreshToken|uid"`).

---

## Work-package to issue index
| WP | Phase | Issues |
|---|---|---|
| WP-1 | 1 | 001, 004, 047, 048, 059, 113 |
| WP-2 | 1 | 007, 008, 051, 112 |
| WP-3 | 1 | 002, 010, 028, 056, 064, 080, 081, 134 |
| WP-4 | 1 | 005, 008, 009, 010, 018, 030, 052, 053, 074, 078, 102, 111, 124 |
| WP-5 | 1 | 003, 011, 017, 034 |
| WP-6 | 1 | 015, 025, 054, 075, 114 |
| WP-7 | 1 | 003, 014, 016, 056 |
| WP-8 | 1 | 017, 057, 098 |
| WP-9 | 2 | 012, 019, 020, 022, 023, 026, 048, 049, 050, 071, 072, 073, 133 |
| WP-10 | 2 | 021, 025, 026, 056, 070, 093 |
| WP-11 | 2 | 018, 024, 027, 053, 058, 066, 097 |
| WP-12 | 2 | 013, 046, 053, 061, 062, 063, 065, 068, 115, 118, 119, 120, 126 |
| WP-13 | 2 | 012, 035, 047, 065, 067, 068, 069, 073, 094, 109, 113, 116, 117 |
| WP-14 | 2 | 056, 094, 103, 108 |
| WP-15 | 2 | 003, 008, 012, 013, 022, 025, 046, 049, 050, 051, 065, 066, 111 |
| WP-16 | 2 | 030, 031, 032, 079, 082, 103, 110 |
| WP-17 | 2 | 033, 053, 056, 076, 099, 103, 135 |
| WP-18 | 2 | 029, 056, 077, 096, 100, 110 |
| WP-19 | 2 | 036, 037, 038, 039, 040, 086, 087, 088, 089, 090, 092, 110, 121, 122, 123, 125, 136 |
| WP-20 | 2 | 006, 036, 041, 042, 043, 044, 045, 060, 083, 085, 087, 088, 091, 092, 122 |
| WP-21 | 2 | 084, 092, 137 |
| WP-22 | 3 | 004, 055, 121 |
| WP-23 | 3 | 001, 002, 003, 012, 061 |
| WP-24 | 3 | 127, 129, 132 |
| WP-25 | 3 | 128, 130 |
| WP-26 | 4 | 101, 107 |
| WP-27 | 4 | 104, 105, 106 |
| WP-28 | 5 | 095 |
| WP-29 | 6 | 131 (plus regression for all High/Critical items) |
