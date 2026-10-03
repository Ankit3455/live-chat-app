# Destined: Final Remediation Report

App: `flutter_webrtc_dating_app_v3` (package `availchat`). Branch: `fix/audit-remediation` (not pushed). Report date: 2026-10-04.
Inputs: `AUDIT.md` (137-issue inventory), `FIX_PLAN.md`, `DECISIONS.md`, `git log main..HEAD`, implementer status per work package (WP), five wave integration checks, and two independent re-audits.

**Status rule used in this report.** When a re-audit gave a verdict, that verdict is the status (136 of 137 issues). DEST-091 had no re-audit verdict, so the implementer's status is used. "Verified fixed" means the fix was confirmed by reading the code. It does **not** mean it was confirmed on a device or by `flutter test`; neither has been run (see section 11).

No secret values appear in this report.

---

## 1. Total issues found

**137 issues** in AUDIT.md (about 190 specialist findings merged into 137 root issues).

| Status | Count |
|---|---|
| Fixed | 111 |
| Partially fixed | 24 |
| Open | 2 |
| **Total** | **137** |

| Severity | Total | Fixed | Partial | Open |
|---|---|---|---|---|
| Critical | 6 | 3 | 3 | 0 |
| High | 39 | 31 | 8 | 0 |
| Medium | 65 | 56 | 9 | 0 |
| Low | 27 | 21 | 4 | 2 |

| Category | Total | Fixed | Partial | Open |
|---|---|---|---|---|
| Security | 26 | 11 | 15 | 0 |
| Functional | 72 | 68 | 4 | 0 |
| Crash | 8 | 6 | 2 | 0 |
| Architecture | 9 | 4 | 3 | 2 |
| UI/UX | 18 | 18 | 0 | 0 |
| Performance | 4 | 4 | 0 | 0 |
| **Total** | **137** | **111** | **24** | **2** |

Most partial items are code-complete and wait on an owner console action (deploying rules/indexes/functions, rotating keys, App Check, signing, TURN, Cloudinary). Both open items are deferred architecture work (WP-24).

---

## 2. Critical issues

| ID | Issue | Status | What is done / what is left |
|---|---|---|---|
| DEST-001 | The repo has no security rules. | Partially fixed (re-audit) | Done: Repo-tracked default-deny rules v1+v2 for Firestore, RTDB, Storage, registered in firebase.json. Left: Rules never compiled or emulator-tested; not deployed; game bodies still client-authoritative; no emailVerified gating; RTDB call consent not enforced. Next: Install Java, run test/rules emulator suite; O-2 export current rules; O-4 deploy after this client ships, backfill run and a minimum-version gate. |
| DEST-002 | Every signed-in user downloads other users' full profile docs: email, DOB, birth time and place, exact GPS, fcmTokens, settings. | Partially fixed (re-audit) | Done: public_profiles mirror (age not DOB, geohash not coordinates); users/{uid} owner-only in v2 rules. Left: Exposure ends only after v2 rules deploy and backfill; public_profiles readable for users with discovery off; client keeps users-doc fallbacks. Next: Deploy mirrorPublicProfile, run backfill_public_profiles.js --apply, deploy v2 rules (O-3, O-4); remove fallbacks afterwards. |
| DEST-003 | Block and Report were fake (snackbar only); Blocked Users tile was a TODO. | Verified fixed (re-audit, code review) | SafetyService: users/{me}/blocked + users/{other}/blockedBy mirror; create-only reports collection; Blocked Users screen; rules refuse messages between blocked pairs; push functions skip blocked pairs; onBlockWritten drops ringing calls; chat input/call buttons hidden when blocked. |
| DEST-004 | Dice, moves, scores, winners, stats and leaderboards are all decided by the client and written straight to Firestore. | Partially fixed (re-audit) | Done: Player-only writes, immutable membership, dice bounds, stats/leaderboard bounds + 10 s throttle. Left: Any player can still write winner/pawnSteps/scores; bounded fake wins possible. Next: WP-22 before coins launch: game callables, Functions-only stats/leaderboards. |
| DEST-005 | New Google users skipped onboarding and were never discoverable. | Verified fixed (re-audit, code review) | First login (or doc without createdAt) writes onboarding defaults (discoveryEnabled:false, signupCompleted:false); cancel returns null; AuthRouter routes to age gate / questionnaire. |
| DEST-006 | Carrom scoring not implemented; every game ended 0-0. | Verified fixed (re-audit, code review) | Pure carrom_rules.dart (resolveShot/resolveTimeout) per DECISIONS: own coin 1, Queen 3 with cover, striker foul -1 (min 0), win on clearing own coins; scores written in the shot transaction. |

Three of the six critical issues are still partial: DEST-001, DEST-002 and DEST-004. DEST-001 and DEST-002 need the rules to be compiled, tested and deployed. DEST-004 needs WP-22.

---

## 3. Security issues

Total 26: fixed 11, partial 15, open 0.

| ID | Sev | Issue | Status |
|---|---|---|---|
| DEST-001 | Critical | The repo has no security rules. | Partial |
| DEST-002 | Critical | Every signed-in user downloads other users' full profile docs: email, DOB, birth time and place, exact GPS, fcmTokens, settings. | Partial |
| DEST-004 | Critical | Dice, moves, scores, winners, stats and leaderboards are all decided by the client and written straight to Firestore. | Partial |
| DEST-007 | High | The OneSignal REST API key is in commit 4b7a124, and the repo is pushed to a GitHub remote. | Partial |
| DEST-008 | High | The client calls `OneSignal.login(uid)` with no JWT, and uids are visible to other users. | Partial |
| DEST-011 | High | Account deletion is a "coming soon" snackbar, and `DatabaseService.deleteUser` is dead code. | Partial |
| DEST-012 | High | The call button checks the caller's own state, and the person who starts a chat is always 'active'. | Partial |
| DEST-013 | High | Uploads use unsigned presets and serve from public URLs forever. | Partial |
| DEST-046 | Medium | A "deleted" message stays visible. | Partial |
| DEST-050 | Medium | Shared public openrelay TURN credentials are hardcoded (no SLA, rate-limited), and transport policy 'all' exposes users' public and LAN IPs to strangers. | Partial |
| DEST-051 | Medium | sendChatPush and sendCallPush have no App Check, no idempotency and no rate limit, so they can be replayed to bomb a user with notifications and burn quota. | Partial |
| DEST-052 | Medium | There is no email verification. | Partial |
| DEST-054 | Medium | The release build is signed with the debug key, so it cannot be published and anyone can sign an "update". | Partial |
| DEST-055 | Medium | Games pair random strangers (the screen says "Play with your matches!"), every client downloads all active matches' names and avatars, and the in-game chat has no block or report. | Partial |
| DEST-112 | Low | Firebase API keys and OAuth client IDs are committed (expected for Firebase), but they need restriction plus App Check to stop scripted abuse such as mass fake signups. | Partial |
| DEST-003 | Critical | Block and Report were fake (snackbar only); Blocked Users tile was a TODO. | Fixed |
| DEST-009 | High | Push identity never bound on signup or unbound on logout; cache not cleared. | Fixed |
| DEST-010 | High | No 18+ gate. | Fixed |
| DEST-014 | High | Mic kept recording after voice sheet dismissed. | Fixed |
| DEST-047 | Medium | Receiver auto-loaded any mediaUrl. | Fixed |
| DEST-048 | Medium | Fake callerId / hijacked rooms in RTDB. | Fixed |
| DEST-049 | Medium | Signalling rooms kept forever under predictable ids. | Fixed |
| DEST-053 | Medium | PII and auth objects logged in release. | Fixed |
| DEST-111 | Low | 'Log out all devices' not enforced. | Fixed |
| DEST-113 | Low | No input length limits. | Fixed |
| DEST-114 | Low | Undeclared foreground-service permissions. | Fixed |

---

## 4. Functional issues

### Functional

Total 72: fixed 68, partial 4, open 0.

| ID | Sev | Issue | Status |
|---|---|---|---|
| DEST-018 | High | PresenceService is a lazy Provider that nothing reads, so it never runs. | Partial |
| DEST-025 | High | The ringtone play() line is commented out (the asset exists). | Partial |
| DEST-068 | Medium | Messages are marked read while the app is backgrounded on ChatScreen. | Partial |
| DEST-075 | Medium | google-services.json has no Android OAuth client (client_type 1 with SHA) for the actual applicationId, so Google sign-in on Android probably fails with DEVELOPER_ERROR (10). | Partial |
| DEST-005 | Critical | New Google users skipped onboarding and were never discoverable. | Fixed |
| DEST-006 | Critical | Carrom scoring not implemented; every game ended 0-0. | Fixed |
| DEST-019 | High | Second incoming call ended the active call. | Fixed |
| DEST-020 | High | Callee could answer before the offer existed. | Fixed |
| DEST-021 | High | Back left call media running with no UI. | Fixed |
| DEST-022 | High | Ghost incoming calls from stale inbox entries. | Fixed |
| DEST-023 | High | Decline and timeout never reached the caller. | Fixed |
| DEST-024 | High | Background/cold-start incoming calls were lost. | Fixed |
| DEST-026 | High | Blank names / callee saw own name on call screens. | Fixed |
| DEST-027 | High | Notification taps did nothing. | Fixed |
| DEST-028 | High | Feed was a live listener on 120 arbitrary docs; filters silently skipped. | Fixed |
| DEST-029 | High | Compatibility chip never computed. | Fixed |
| DEST-030 | High | No profile-completion gate; back landed on Login. | Fixed |
| DEST-031 | High | Cursor jumps in text questions. | Fixed |
| DEST-032 | High | Saved multi-choice answers showed unselected. | Fixed |
| DEST-033 | High | Reset to Avatar nulled the profile image. | Fixed |
| DEST-034 | High | Most Settings tiles did nothing; dev options in release. | Fixed |
| DEST-035 | High | Edit created a duplicate message. | Fixed |
| DEST-036 | High | Disconnected turn holder froze Ludo/Carrom. | Fixed |
| DEST-037 | High | Backgrounding briefly forfeited a 2-player Ludo game. | Fixed |
| DEST-038 | High | Resume reset pawns to home. | Fixed |
| DEST-039 | High | Turns went to players who left. | Fixed |
| DEST-040 | High | Same players matched into two games. | Fixed |
| DEST-041 | High | Either player could shoot at any time in Carrom. | Fixed |
| DEST-042 | High | Carrom boards diverged; result screen pushed twice. | Fixed |
| DEST-043 | High | Simultaneous Carrom searchers never paired. | Fixed |
| DEST-044 | High | Carrom non-host stuck on VS screen. | Fixed |
| DEST-045 | High | Leaving Carrom had no forfeit; host reset mid-game. | Fixed |
| DEST-061 | Medium | Whole-map participantData rewrites without transaction. | Fixed |
| DEST-062 | Medium | Duplicate conversations for the same pair. | Fixed |
| DEST-063 | Medium | Opening a chat created an empty conversation. | Fixed |
| DEST-064 | Medium | DOB stored three ways; cast dropped users. | Fixed |
| DEST-065 | Medium | Media messages sent no push. | Fixed |
| DEST-066 | Medium | Chat pushes ignored mute, 'new' state and settings. | Fixed |
| DEST-067 | Medium | Cleared messages came back. | Fixed |
| DEST-069 | Medium | Text lost on send failure; Send blocked by push. | Fixed |
| DEST-070 | Medium | Incoming screen kept ringing after caller hung up. | Fixed |
| DEST-071 | Medium | Dropped peer left call open forever. | Fixed |
| DEST-072 | Medium | Failed answer leaked PeerConnection and inbox entry. | Fixed |
| DEST-073 | Medium | No missed-call records. | Fixed |
| DEST-074 | Medium | Login always showed a generic error. | Fixed |
| DEST-076 | Medium | Avatars ignored answers. | Fixed |
| DEST-077 | Medium | Astrology answers leaked across accounts. | Fixed |
| DEST-078 | Medium | Orphaned Auth accounts on failed signup. | Fixed |
| DEST-079 | Medium | hereFor never displayed; city overwrote birth location. | Fixed |
| DEST-080 | Medium | Discovery prefs leaked across accounts. | Fixed |
| DEST-081 | Medium | Location capture failed silently. | Fixed |
| DEST-082 | Medium | Double-tap Finish pushed twice; completion % wrong. | Fixed |
| DEST-083 | Medium | Carrom sounds missing. | Fixed |
| DEST-084 | Medium | Love Physics unreachable and unwinnable. | Fixed |
| DEST-085 | Medium | Carrom boards misaligned across screen sizes. | Fixed |
| DEST-086 | Medium | Ludo chat hid messages after the 100th. | Fixed |
| DEST-087 | Medium | Stale queue entries matched. | Fixed |
| DEST-088 | Medium | Bonus turns did not reset the timer. | Fixed |
| DEST-089 | Medium | Illegal Ludo pawn moves on a 6. | Fixed |
| DEST-090 | Medium | Timeout vs move race. | Fixed |
| DEST-091 | Medium | Carrom stats saved twice. | Fixed |
| DEST-092 | Medium | Game dead ends and fake buttons. | Fixed |
| DEST-115 | Low | Typing indicator stuck on. | Fixed |
| DEST-116 | Low | Audio state on wrong message. | Fixed |
| DEST-117 | Low | Mute icon never shown. | Fixed |
| DEST-118 | Low | Delete chat showed full history on reopen. | Fixed |
| DEST-119 | Low | Uploads hung forever; doubled paths. | Fixed |
| DEST-120 | Low | Unread badge counted deleted chats. | Fixed |
| DEST-121 | Low | 'Win to earn points' promise. | Fixed |
| DEST-122 | Low | Game sounds from build(), cut off. | Fixed |
| DEST-123 | Low | Fast phone clock timed out turns. | Fixed |
| DEST-124 | Low | Splash double navigation. | Fixed |

### Crash

Total 8: fixed 6, partial 2, open 0.

| ID | Sev | Issue | Status |
|---|---|---|---|
| DEST-015 | High | Info.plist has no camera, microphone, photo or location usage strings, so iOS kills the app the first time any of these is used. | Partial |
| DEST-059 | Medium | Matchmaking queries need composite indexes that are not in the repo. | Partial |
| DEST-016 | High | LateInitializationError when chat init fails. | Fixed |
| DEST-017 | High | Help-sheet tutorial popped twice (black screen). | Fixed |
| DEST-056 | Medium | setState/context after await; notify after dispose. | Fixed |
| DEST-057 | Medium | Duplicate GlobalKey crash with two HomeScreens. | Fixed |
| DEST-058 | Medium | Bootstrap order bugs. | Fixed |
| DEST-060 | Medium | pubspec declared missing assets/icons/. | Fixed |

Crash is a separate category in AUDIT.md (8 issues). It is listed here under Functional so every issue appears in a category section.

---

## 5. Architecture issues

Total 9: fixed 4, partial 3, open 2.

| ID | Sev | Issue | Status |
|---|---|---|---|
| DEST-129 | Low | carrom_game_screen mixes sync, rules, timer and Forge2D components in one file. | Open |
| DEST-132 | Low | Environment config is hardcoded (Cloudinary cloud name and presets, OneSignal app id duplicated, TURN credentials, media flags). | Open |
| DEST-127 | Low | There is no consistent data layer: 53 FirebaseFirestore.instance calls in 24 UI files. | Partial |
| DEST-130 | Low | Unused heavy dependencies (google_mlkit_translation, location, wakelock_plus, uuid, device_info_plus, google_fonts, badges, confetti). | Partial |
| DEST-131 | Low | The only test does not compile (wrong package name, a MyApp class that doesn't exist). | Partial |
| DEST-097 | Medium | Dead FCM stack beside OneSignal. | Fixed |
| DEST-125 | Low | Ludo provider never disposed. | Fixed |
| DEST-126 | Low | Duplicated conversation summary fields. | Fixed |
| DEST-128 | Low | God files mostly commented-out code. | Fixed |

---

## 6. UI/UX issues

Total 18: fixed 18, partial 0, open 0.

| ID | Sev | Issue | Status |
|---|---|---|---|
| DEST-098 | Medium | Home tour returned after Skip. | Fixed |
| DEST-099 | Medium | Change Avatar on My Profile was a stub. | Fixed |
| DEST-100 | Medium | Astrology flow had 10 routes. | Fixed |
| DEST-101 | Medium | Search, bell and drawer still on Home. | Fixed |
| DEST-102 | Medium | Login button invisible; weak form UX. | Fixed |
| DEST-103 | Medium | Endless spinners and discarded refresh data. | Fixed |
| DEST-104 | Medium | Two colour systems; font not loaded. | Fixed |
| DEST-105 | Medium | Text contrast failed WCAG. | Fixed |
| DEST-106 | Medium | Missing tooltips and semantics. | Fixed |
| DEST-107 | Medium | Bottom nav only on Home; stack grew. | Fixed |
| DEST-108 | Medium | Chat list delete without confirmation. | Fixed |
| DEST-109 | Medium | Reply bubble showed hardcoded text. | Fixed |
| DEST-110 | Medium | Fixed layouts overflow. | Fixed |
| DEST-133 | Low | Call duration counted from dialing. | Fixed |
| DEST-134 | Low | Discovery filter UX gaps. | Fixed |
| DEST-135 | Low | Edit Profile photo row overflow. | Fixed |
| DEST-136 | Low | Ludo board ordering/colour issues. | Fixed |
| DEST-137 | Low | Game stats never refreshed; spun when signed out. | Fixed |

---

## 7. Performance issues

Total 4: fixed 4, partial 0, open 0.

| ID | Sev | Issue | Status |
|---|---|---|---|
| DEST-093 | Medium | AudioCallScreen leaked listeners. | Fixed |
| DEST-094 | Medium | Streams created in build. | Fixed |
| DEST-095 | Medium | Lobbies scanned all matches. | Fixed |
| DEST-096 | Medium | Per-card endless animations. | Fixed |

---

## 8. Issues fixed

One row for each of the 111 issues with status Fixed. Validation lists the static check that was done and the device check that is still pending. Partially fixed issues are in section 9.

| ID | Original issue | Root cause | Fix | Test / validation | Result |
|---|---|---|---|---|---|
| DEST-003 | Block and Report were fake (snackbar only); Blocked Users tile was a TODO. | No storage or enforcement existed for blocks or reports. | SafetyService: users/{me}/blocked + users/{other}/blockedBy mirror; create-only reports collection; Blocked Users screen; rules refuse messages between blocked pairs; push functions skip blocked pairs; onBlockWritten drops ringing calls; chat input/call buttons hidden when blocked. | Code review against rules; rules tests written (not run). Device: block from chat, confirm other side loses input/calls; report saved in console. | Verified fixed (re-audit, code review) |
| DEST-005 | New Google users skipped onboarding and were never discoverable. | signInWithGoogle merge-wrote profile on every login with no first-login branch; login always routed to Home. | First login (or doc without createdAt) writes onboarding defaults (discoveryEnabled:false, signupCompleted:false); cancel returns null; AuthRouter routes to age gate / questionnaire. | dart format parse; caller grep. Device: new Google account lands on age gate then questionnaire. | Verified fixed (re-audit, code review) |
| DEST-006 | Carrom scoring not implemented; every game ended 0-0. | _finalizeShot only did scores.putIfAbsent(0). | Pure carrom_rules.dart (resolveShot/resolveTimeout) per DECISIONS: own coin 1, Queen 3 with cover, striker foul -1 (min 0), win on clearing own coins; scores written in the shot transaction. | dart analyze on carrom_rules.dart clean; standalone Dart script of the rule cases; carrom_rules_test.dart written (not run). Rule interpretations need owner confirmation. | Verified fixed (re-audit, code review) |
| DEST-009 | Push identity never bound on signup or unbound on logout; cache not cleared. | OneSignal bound only in login screen; two divergent sign-out paths. | SessionService singleton: authStateChanges drives OneSignal.login + presence; single signOut does presence offline, token removal, OneSignal logout, Google/Firebase sign-out, Firestore terminate+clearPersistence, account prefs cleared. | Grep: OneSignal login/logout and auth signOut only in session_service. Device: log out, log in as another user, no cross-account pushes. | Verified fixed (re-audit, code review) |
| DEST-010 | No 18+ gate. | Feed age filter off by default; no DOB requirement; mirror published minors. | DOB required; under-18 routed to underage screen; feed excludes unknown/<18 ages; mirror publishes discoveryEnabled only when age>=18; rules reject a timestamp DOB under 18. | Node stub test of mirror; code review. Device: legacy account with no DOB does not appear in feed. | Verified fixed (re-audit, code review) |
| DEST-014 | Mic kept recording after voice sheet dismissed. | dispose only cancelled the timer; parent popped blindly. | Sheet pops itself with a result; _finishing guard; dispose cancels active recording; PopScope discard confirm; Open Settings on denial. | Code review. Device: start recording, press back, mic indicator turns off. | Verified fixed (re-audit, code review) |
| DEST-016 | LateInitializationError when chat init fails. | late _conversationId read before async assignment. | Nullable id, init error state with Retry; streams built only after id is set. | Grep; parse check. Device: open new chat in airplane mode, see Retry screen. | Verified fixed (re-audit, code review) |
| DEST-017 | Help-sheet tutorial popped twice (black screen). | Double Navigator.pop removed root HomeScreen. | Drawer removed (WP-26); tutorial launched via callback with a single pop; Settings uses replay hint. | Grep of call sites. Device: Settings > View App Tutorial. | Verified fixed (re-audit, code review) |
| DEST-019 | Second incoming call ended the active call. | No call state machine; reject ran endCall on the current call. | CallPhase state machine; operations scoped by callId; busy auto-reject with endReason busy; rejectCall no longer ends the active call. | Grep (no endCall in rejectCall); call_service_test.dart written (not run). Device: A-B in call, C calls A. | Verified fixed (re-audit, code review) |
| DEST-020 | Callee could answer before the offer existed. | Inbox entry and push written before SDP offer. | Order: consent, permission, offer, onDisconnect, inbox, push; callee waitForOffer tolerates late offer. | Code review of ordering. Device: answer immediately. | Verified fixed (re-audit, code review) |
| DEST-021 | Back left call media running with no UI. | Call lifecycle tied to the red button; dispose skipped endCall. | ActiveCallScreenMixin: PopScope confirm, follows phase, ends live call on dispose, wakelock. | Parse check; grep. Device: press back during call. | Verified fixed (re-audit, code review) |
| DEST-022 | Ghost incoming calls from stale inbox entries. | Inbox entries never removed; onChildAdded replayed them. | Caller marks/removes entry on cancel/end/fail; callee clears own entry; listener drops stale/non-ringing entries by server time; scheduled sweep. | Code review. Device: caller hangs up, restart callee, no ghost call. | Verified fixed (re-audit, code review) |
| DEST-023 | Decline and timeout never reached the caller. | Decline wrote to the wrong call; no no-answer timer. | Decline writes endReason to the room; caller maps reasons; 45 s no-answer timer. | Code review. Device: decline and no-answer cases. | Verified fixed (re-audit, code review) |
| DEST-024 | Background/cold-start incoming calls were lost. | Call marked shown before push; splash replaced the incoming screen. | Show only in foreground after router is ready; retry on resume; shown id set after push. | Parse check. Device: background app, receive call, reopen within 30 s. | Verified fixed (re-audit, code review) |
| DEST-026 | Blank names / callee saw own name on call screens. | receiverName '' with ?? fallback; avatar ignored. | CallModel.otherNameFor/otherAvatarFor; CallService loads profile cards from public_profiles/users. | Parse check. Device: both sides see the other's name and photo. | Verified fixed (re-audit, code review) |
| DEST-027 | Notification taps did nothing. | No OneSignal click listener; local tap only printed. | PendingIntent + PendingIntentRouter queue drained after splash; OneSignal click listener; handles chat, call and missed_call. | Grep; parse. Device: tap chat push from killed state. | Verified fixed (re-audit, code review) |
| DEST-028 | Feed was a live listener on 120 arbitrary docs; filters silently skipped. | Current user looked up inside the feed; no orderBy or pagination. | Own doc loaded separately; paginated get() ordered by lastSeen (30 per page); loadMore on scroll; indexes added. | Code review. Device: distance filter with discovery off; scroll past 30. | Verified fixed (re-audit, code review) |
| DEST-029 | Compatibility chip never computed. | Score functions had no callers; matchPercentage never written. | CompatibilityService (sun-sign table + preferred-sign bonus) shown as chip on ProfileCard; card tap opens quick sheet. | Parse; compatibility_utils_test.dart written (not run). Device: chip visible on cards. | Verified fixed (re-audit, code review) |
| DEST-030 | No profile-completion gate; back landed on Login. | Splash/login routed straight to Home; no PopScope in onboarding. | AuthRouter resolveStartDestination (DOB, verify, questionnaire, post-signup); PopScope steps back one question. | Code review. Device: back inside questionnaire. | Verified fixed (re-audit, code review) |
| DEST-031 | Cursor jumps in text questions. | New TextEditingController on every build. | Controller created in initState; didUpdateWidget syncs only when text differs. | Grep; QuestionWidget widget tests written (not run). | Verified fixed (re-audit, code review) |
| DEST-032 | Saved multi-choice answers showed unselected. | List<dynamic> failed `is List<String>`; late answers ignored. | _normalize handles List<dynamic>/legacy String; didUpdateWidget applies late answers. | Grep; widget tests written (not run). | Verified fixed (re-audit, code review) |
| DEST-033 | Reset to Avatar nulled the profile image. | Read avatarPngUrl; generator writes avatarImageUrl. | ProfilePhotoService.resetToAvatar reads avatarImageUrl, regenerates if missing, never writes null. | Grep. Device: upload photo, then reset. | Verified fixed (re-audit, code review) |
| DEST-034 | Most Settings tiles did nothing; dev options in release. | TODO tiles; no kDebugMode gate. | Working tiles per DECISIONS; Discovery, Notifications, Blocked users, legal links (placeholders), Delete account; dev section only under kDebugMode; Change Password only for password provider. | Grep. Device: every tile on a release build. | Verified fixed (re-audit, code review) |
| DEST-035 | Edit created a duplicate message. | Edit only copied text into input. | Editing state calls ChatService.editMessage (editedAt, preview refresh, no push). | Device: edit own message. | Verified fixed (re-audit, code review) |
| DEST-036 | Disconnected turn holder froze Ludo/Carrom. | Only the holder's device could time out its turn. | Any participant can pass a stalled turn after grace, guarded by turnSeq in a transaction. | Parse. Device: kill the turn holder's app. | Verified fixed (re-audit, code review) |
| DEST-037 | Backgrounding briefly forfeited a 2-player Ludo game. | Pause treated as leave. | Away status with 60 s grace; expireAway transaction (forfeit in 2-player, skip in 4-player). | Parse. Device: background 5 s, then >60 s. | Verified fixed (re-audit, code review) |
| DEST-038 | Resume reset pawns to home. | playerReconnect/playerLeft rewrote pawnSteps. | Reconnect/leave change only status/activeColors. | Grep. Device: background and resume mid-game. | Verified fixed (re-audit, code review) |
| DEST-039 | Turns went to players who left. | _activeColors built from all players. | Active colours from server; commitMove writes only moving/captured colours. | Parse. Device: 4-player, one leaves. | Verified fixed (re-audit, code review) |
| DEST-040 | Same players matched into two games. | Matchmaking transaction did not claim queue docs. | Queue doc per uid; one transaction reads, validates and deletes all claimed docs and creates the match. | Parse. Device: two phones search at the same second. | Verified fixed (re-audit, code review) |
| DEST-041 | Either player could shoot at any time in Carrom. | No turn gating on input. | canShoot gate; striker limited to own baseline; shot written in a turn-checked transaction. | Analyzer against stub Flame APIs. Device: waiting player cannot move striker. | Verified fixed (re-audit, code review) |
| DEST-042 | Carrom boards diverged; result screen pushed twice. | Mixed sync models, no move dedupe, local pocket detection on receiver. | Snapshot-only sync keyed by moveSeq, applied once; tweened opponent coins; single result push. | Device: 10 shots, positions match on both phones. | Verified fixed (re-audit, code review) |
| DEST-043 | Simultaneous Carrom searchers never paired. | Queue checked once; old matches accepted. | Queue doc per uid with expiry; 3 s re-scan; claim in transaction; createdAt filter. | Device: both tap Find Match together. | Verified fixed (re-audit, code review) |
| DEST-044 | Carrom non-host stuck on VS screen. | Missed 'started' event; no timeout. | joined flags; host starts in transaction; listener navigates on started; join timeout cancels. | Device: host kills app on VS screen. | Verified fixed (re-audit, code review) |
| DEST-045 | Leaving Carrom had no forfeit; host reset mid-game. | Back just popped; refresh reset board. | Leave dialog with transactional forfeit; reset removed; rematch needs both players. | Device: back during play. | Verified fixed (re-audit, code review) |
| DEST-047 | Receiver auto-loaded any mediaUrl. | No URL validation. | Rules restrict mediaUrl to the project's Cloudinary cloud / Storage bucket (<=2048 chars); client refuses other hosts. | Rules tests written (not run); code review. | Verified fixed (re-audit, code review) |
| DEST-048 | Fake callerId / hijacked rooms in RTDB. | Inbox and rooms writable by anyone. | Inbox write requires callerId == auth.uid and a room naming this caller and callee; callee shows profile name, not payload. | database.test.js written (not run); code review. | Verified fixed (re-audit, code review) |
| DEST-049 | Signalling rooms kept forever under predictable ids. | Rooms never deleted; uid_uid_millis ids. | Random uuid ids; party-only access; client deletes room after call; scheduled sweep. | Code review. Device: room disappears after a call. | Verified fixed (re-audit, code review) |
| DEST-053 | PII and auth objects logged in release. | Unguarded debugPrint/print. | No print(); uid/email logs kDebugMode-only; avoid_print lint. | Grep. Device: release logcat check. | Verified fixed (re-audit, code review) |
| DEST-056 | setState/context after await; notify after dispose. | No mounted checks or disposed guards. | Mounted checks, disposed guards, post-frame loads across screens; lints enabled. | Spot-checked by re-audit. | Verified fixed (re-audit, code review) |
| DEST-057 | Duplicate GlobalKey crash with two HomeScreens. | Static tour GlobalKeys. | Per-instance HomeTourKeys; single HomeScreen inside MainShell. | Grep. Residual: DiscoveryOnboarding static keys (low risk). | Verified fixed (re-audit, code review) |
| DEST-058 | Bootstrap order bugs. | Firestore used before settings; initializeApp without options; startup blocked. | New order: initializeApp(options), ErrorHandler, App Check, bounded caches, OneSignal without prompt, then runApp; permission asked after sign-in. | Code review. | Verified fixed (re-audit, code review) |
| DEST-060 | pubspec declared missing assets/icons/. | Stale asset entry. | Entry removed; every declared asset folder exists. | Re-audit check of pubspec. | Verified fixed (re-audit, code review) |
| DEST-061 | Whole-map participantData rewrites without transaction. | Read-then-rewrite on every send. | Single batch writer with merge and FieldValue.increment. | Grep; parse. | Verified fixed (re-audit, code review) |
| DEST-062 | Duplicate conversations for the same pair. | Query-then-create with random id. | Deterministic sorted id with legacy lookup. | Grep. Device: both open each other's chat. | Verified fixed (re-audit, code review) |
| DEST-063 | Opening a chat created an empty conversation. | Eager create on open. | No write on open; first message creates doc; empty conversations hidden. | Device: open and leave without sending. | Verified fixed (re-audit, code review) |
| DEST-064 | DOB stored three ways; cast dropped users. | Inconsistent types; hard as String? cast. | Single parseDob for all formats; age derived; AgePolicy delegates to it. | user_model_test/age_policy_test written (not run). | Verified fixed (re-audit, code review) |
| DEST-065 | Media messages sent no push. | Media senders never called push; body text-only. | onDocumentCreated trigger pushes every message type with type-based body. | functions unit tests (7/7 pass, node --test). | Verified fixed (re-audit, code review) |
| DEST-066 | Chat pushes ignored mute, 'new' state and settings. | Single high-importance channel; no checks. | Skip when muted/deleted/blocked/disabled; silent channel for 'new' chats; foreground suppression for the open chat. | Unit tests for stateFor/isMuted (pass). Device: muted chat gets no push. | Verified fixed (re-audit, code review) |
| DEST-067 | Cleared messages came back. | Listener kept old cutoff; offline inserts out of order. | List resets when server clearedBefore changes; sorted inserts. | Device: clear, then other side reacts to old messages. | Verified fixed (re-audit, code review) |
| DEST-069 | Text lost on send failure; Send blocked by push. | Input cleared before send; push awaited. | Text restored on failure; push fire-and-forget. | Device: send in airplane mode. | Verified fixed (re-audit, code review) |
| DEST-070 | Incoming screen kept ringing after caller hung up. | No room/inbox listener; no tap guard. | Listens to room and inbox; _handled guard; back rejects. | Device: caller cancels. | Verified fixed (re-audit, code review) |
| DEST-071 | Dropped peer left call open forever. | No connection/ICE state handling. | Reconnecting phase with ICE restart and 15 s grace, then ends. | Device: kill callee mid-call; toggle Wi-Fi. | Verified fixed (re-audit, code review) |
| DEST-072 | Failed answer leaked PeerConnection and inbox entry. | No permission pre-check or failure cleanup. | Permission check first; on failure room set failed, inbox cleared, peer disposed. | Device: deny mic on callee. | Verified fixed (re-audit, code review) |
| DEST-073 | No missed-call records. | Nothing written for missed/declined. | Call-type messages for declined/busy/missed; missed and busy push. | Device: no answer 45 s. | Verified fixed (re-audit, code review) |
| DEST-074 | Login always showed a generic error. | FirebaseAuthException wrapped in Exception. | Exception propagates; codes mapped to friendly text. | Device: wrong password. | Verified fixed (re-audit, code review) |
| DEST-076 | Avatars ignored answers. | Only seed sent to DiceBear. | Explicit avataaars params from props; DOB/bio no longer stored in avatarProperties. | Device: male/female test accounts. | Verified fixed (re-audit, code review) |
| DEST-077 | Astrology answers leaked across accounts. | Global never-reset view model; label/bool mismatch. | Scoped view model, preload, dirty-field saves, boolean believesInAstrology. | Device: log out A, log in B. | Verified fixed (re-audit, code review) |
| DEST-078 | Orphaned Auth accounts on failed signup. | Account created before profile write. | Retry write; delete Auth user if still failing; recover on email-already-in-use. | Device: airplane mode right after Sign Up. | Verified fixed (re-audit, code review) |
| DEST-079 | hereFor never displayed; city overwrote birth location. | String vs List mismatch; field collision. | hereFor multi-choice accepting String/List; birthLocation separate; currentCity added. | Code review. | Verified fixed (re-audit, code review) |
| DEST-080 | Discovery prefs leaked across accounts. | Device-global SharedPreferences. | Keys per uid; visibility read from users/{uid}; save with timeout/error handling. | Device: set filters as A, sign in as B. | Verified fixed (re-audit, code review) |
| DEST-081 | Location capture failed silently. | No service/permission checks; city edit did not re-geocode. | LocationService with typed results and settings links; coarse coordinates + geohash; re-geocode on city edit. | Device: location service off. | Verified fixed (re-audit, code review) |
| DEST-082 | Double-tap Finish pushed twice; completion % wrong. | No busy guard; fire-and-forget completion. | Busy guards; mandatory check; awaited completion; per-uid banner prefs. | Device: double-tap Finish. | Verified fixed (re-audit, code review) |
| DEST-083 | Carrom sounds missing. | Asset files absent, folder undeclared. | Reuse declared assets/sounds files. | Device: strike, pocket, foul, result. | Verified fixed (re-audit, code review) |
| DEST-084 | Love Physics unreachable and unwinnable. | Only entry was a duplicate class; win threshold below radii. | Card in game list; threshold uses radii; old lines removed. | Parse only; needs flutter analyze + device for flame_forge2d 0.19 API. | Verified fixed (re-audit, code review) |
| DEST-085 | Carrom boards misaligned across screen sizes. | Device-dependent board size with absolute sync. | Fixed 40-unit logical board; camera zoom; guest view rotated. | Device: small and large phones; physics tuning needed. | Verified fixed (re-audit, code review) |
| DEST-086 | Ludo chat hid messages after the 100th. | Ascending limit(100); stream in build. | Descending newest 100 reversed; stream in initState; auto-scroll; 300-char cap. | Device: 120 messages. | Verified fixed (re-audit, code review) |
| DEST-087 | Stale queue entries matched. | Entries never expired. | expiresAt + heartbeat filter; scheduled sweep; Carrom orders by expiresAt. | Code review. TTL policy (O-12) recommended. | Verified fixed (re-audit, code review) |
| DEST-088 | Bonus turns did not reset the timer. | turnSeq not bumped on bonus turns. | Every turn bumps turnSeq and resets countdown. | Device: roll a 6. | Verified fixed (re-audit, code review) |
| DEST-089 | Illegal Ludo pawn moves on a 6. | No legality function. | LudoRules.targetStep/legalPawns used for highlight and in commitMove. | ludo_rules_test.dart written (not run). | Verified fixed (re-audit, code review) |
| DEST-090 | Timeout vs move race. | Unchecked turnColor writes. | All turn writes are guarded transactions. | Grep for runTransaction. | Verified fixed (re-audit, code review) |
| DEST-091 | Carrom stats saved twice. | Read-modify-write outside a transaction; no history check. | One transaction; skips if carrom_history/{matchId} exists. | Static analysis against cloud_firestore 5.6.12. Not re-audited. | Fixed per implementer; not re-audited |
| DEST-092 | Game dead ends and fake buttons. | Placeholder classes and pop-based navigation. | Back to Lobby goes to lobby; result CHAT opens ChatScreen; real leaderboard. | Device: finish a game. | Verified fixed (re-audit, code review) |
| DEST-093 | AudioCallScreen leaked listeners. | Subscriptions never cancelled. | Remote subscription cancelled in dispose; no-op listener removed. | Grep. | Verified fixed (re-audit, code review) |
| DEST-094 | Streams created in build. | Re-subscribe on every setState. | Streams in initState; per-uid user future cache. | Grep. Residual: profile_edit_screen snapshots() in build. | Verified fixed (re-audit, code review) |
| DEST-095 | Lobbies scanned all matches. | Unbounded listeners/polling. | Queries on playerUids arrayContains me, from search start, limited. | Grep; index JSON valid. | Verified fixed (re-audit, code review) |
| DEST-096 | Per-card endless animations. | One AnimationController per card; no reduced motion. | One shared ref-counted ticker; respects disableAnimations. | Code review (description-based). | Verified fixed (re-audit, code review) |
| DEST-097 | Dead FCM stack beside OneSignal. | Server only used OneSignal. | FCM handlers and firebase_messaging removed; OneSignal handles taps/foreground. | Grep. | Verified fixed (re-audit, code review) |
| DEST-098 | Home tour returned after Skip. | Skip treated as 'later'; fixed-delay start; device-wide prefs. | Skip permanent; start when data ready; per-uid prefs. | Grep. | Verified fixed (re-audit, code review) |
| DEST-099 | Change Avatar on My Profile was a stub. | Working actions lived in Edit Profile. | Change Avatar sheet on My Profile with upload/reset/generate. | Device: each option. | Verified fixed (re-audit, code review) |
| DEST-100 | Astrology flow had 10 routes. | Pushed step screens, duplicate questions. | Single PageView flow; step screens deleted. | Device: Profile > Astrology. | Verified fixed (re-audit, code review) |
| DEST-101 | Search, bell and drawer still on Home. | Not removed. | Replaced with Discover header + filters button; drawer removed. | Grep. | Verified fixed (re-audit, code review) |
| DEST-102 | Login button invisible; weak form UX. | Transparent button; shared validator. | CustomButton, separate validators, visibility toggle, autofill, submit guard. | Device: login screen. | Verified fixed (re-audit, code review) |
| DEST-103 | Endless spinners and discarded refresh data. | Loading cleared only on success. | Error/retry states; content kept during refresh. | Device: missing user doc. | Verified fixed (re-audit, code review) |
| DEST-104 | Two colour systems; font not loaded. | Hardcoded literals; Montserrat never loaded. | Single AppColors palette with aliases; google_fonts Montserrat. | Parse check on 60 files; AppColors member script. | Verified fixed (re-audit, code review) |
| DEST-105 | Text contrast failed WCAG. | Brand purple used as text on dark. | brandPurpleLight/lavender on dark surfaces. | WCAG ratio script. | Verified fixed (re-audit, code review) |
| DEST-106 | Missing tooltips and semantics. | Unlabelled IconButtons/GestureDetectors. | Tooltips on all IconButtons; Semantics on custom controls; bottom-nav Semantics regression fixed in 86cb1b8. | Static IconButton scan. Device: TalkBack/VoiceOver. | Verified fixed (re-audit, code review) |
| DEST-107 | Bottom nav only on Home; stack grew. | Tabs pushed full screens. | MainShell IndexedStack (Discover, Chats, Games, Profile) with persistent nav in SafeArea. | Grep. Device: switch tabs, back. | Verified fixed (re-audit, code review) |
| DEST-108 | Chat list delete without confirmation. | Immediate deleteForUser. | Confirm dialog; labelled actions; non-blocking navigation; New-tab badge. | Device: swipe Delete then Cancel. | Verified fixed (re-audit, code review) |
| DEST-109 | Reply bubble showed hardcoded text. | No reply snapshot. | replyTo snapshot (capped at 2000 chars in b13eacf); tap scrolls to original. | Grep. Device: reply and tap quote. | Verified fixed (re-audit, code review) |
| DEST-110 | Fixed layouts overflow. | Non-scrolling columns; width-only board. | Scrollable screens; board sized by min(w,h). | Device: small screen/landscape. | Verified fixed (re-audit, code review) |
| DEST-111 | 'Log out all devices' not enforced. | revokeSessions function missing. | revokeSessions callable revokes refresh tokens (rate-limited). | Contract check vs auth_service. Device: two devices, change password. | Verified fixed (re-audit, code review) |
| DEST-113 | No input length limits. | No server caps. | Rules size() caps on text fields, messages, previews, replies, reports, RTDB names; chat maxLength 2000. | Rules tests written (not run). | Verified fixed (re-audit, code review) |
| DEST-114 | Undeclared foreground-service permissions. | Template/copy-paste permissions. | Duplicate and unused permissions removed. | Manifest parse (xmllint). | Verified fixed (re-audit, code review) |
| DEST-115 | Typing indicator stuck on. | Bool with no expiry. | Timestamp heartbeat with 5 s receiver expiry. | Device: kill app while typing. | Verified fixed (re-audit, code review) |
| DEST-116 | Audio state on wrong message. | No list keys. | ValueKey per message; AudioMessage resets on change. | Device: play voice note while receiving. | Verified fixed (re-audit, code review) |
| DEST-117 | Mute icon never shown. | Read legacy muted map. | Reads isMuted(myUid) from participantData. | Device: mute from chat list. | Verified fixed (re-audit, code review) |
| DEST-118 | Delete chat showed full history on reopen. | Only hid the row. | Delete sets clearedBefore (WhatsApp-style). | Device: delete, then other user sends. | Verified fixed (re-audit, code review) |
| DEST-119 | Uploads hung forever; doubled paths. | No timeout; folder + public_id. | 60 s timeout + one retry; folder and public_id separate. | Device: upload in airplane mode. | Verified fixed (re-audit, code review) |
| DEST-120 | Unread badge counted deleted chats. | Separate query; as int cast. | Shared ConversationsRepository; visibleUnreadFor. | Grep. | Verified fixed (re-audit, code review) |
| DEST-121 | 'Win to earn points' promise. | Points never awarded. | Row removed per DECISIONS. | Grep. | Verified fixed (re-audit, code review) |
| DEST-122 | Game sounds from build(), cut off. | Single player; build-triggered. | Pool of players; play once on state change; no defeat sound on draw. | Code review. | Verified fixed (re-audit, code review) |
| DEST-123 | Fast phone clock timed out turns. | Device clock vs server timestamp. | Countdown from snapshot arrival. | Device: clock 2 min ahead. | Verified fixed (re-audit, code review) |
| DEST-124 | Splash double navigation. | Timer and CTA both navigated. | Shared _navigated guard. | Device: tap CTA at ~2 s. | Verified fixed (re-audit, code review) |
| DEST-125 | Ludo provider never disposed. | No dispose; writes after leave. | Disposed; guarded notify; stopActions before Leave. | Code review. | Verified fixed (re-audit, code review) |
| DEST-126 | Duplicated conversation summary fields. | Multiple writers, mixed types. | Canonical lastMessage map + lastMessageAt Timestamps; optional migration script. | node --check; parse. | Verified fixed (re-audit, code review) |
| DEST-128 | God files mostly commented-out code. | Old versions kept as comments. | Commented blocks removed; 26 unreachable files deleted (import-graph check). | Grep for deleted symbols; import-resolution script. | Verified fixed (re-audit, code review) |
| DEST-133 | Call duration counted from dialing. | Ticker started on dial. | Starts on first connect; video screen ticks every 1 s. | Device: duration 00:00 until connect. | Verified fixed (re-audit, code review) |
| DEST-134 | Discovery filter UX gaps. | Controls active while off; Hinglish; no guard. | Disabled controls; English copy; discard guard. | Lint clean on screen. | Verified fixed (re-audit, code review) |
| DEST-135 | Edit Profile photo row overflow. | Fixed Row. | Full-width ListTiles in My Profile sheet with preview. | Device: 360dp emulator. | Verified fixed (re-audit, code review) |
| DEST-136 | Ludo board ordering/colour issues. | Inconsistent comparator; adjacent colours. | Stable sort; opposite colours for 2-player; random first turn; only board colours drawn. | Parse. | Verified fixed (re-audit, code review) |
| DEST-137 | Game stats never refreshed; spun when signed out. | Loaded once; early return skipped clearing. | Reload after navigation; signed-out path clears spinner. | Device: play, return, stats updated. | Verified fixed (re-audit, code review) |

---

## 9. Issues still remaining

24 partially fixed and 2 open.

| ID | Sev | Status | Reason | Done so far | Still missing | Next step |
|---|---|---|---|---|---|---|
| DEST-001 | Critical | Partial | Owner console action; WP-22 deferred | Repo-tracked default-deny rules v1+v2 for Firestore, RTDB, Storage, registered in firebase.json. | Rules never compiled or emulator-tested; not deployed; game bodies still client-authoritative; no emailVerified gating; RTDB call consent not enforced. | Install Java, run test/rules emulator suite; O-2 export current rules; O-4 deploy after this client ships, backfill run and a minimum-version gate. |
| DEST-002 | Critical | Partial | Owner console action | public_profiles mirror (age not DOB, geohash not coordinates); users/{uid} owner-only in v2 rules. | Exposure ends only after v2 rules deploy and backfill; public_profiles readable for users with discovery off; client keeps users-doc fallbacks. | Deploy mirrorPublicProfile, run backfill_public_profiles.js --apply, deploy v2 rules (O-3, O-4); remove fallbacks afterwards. |
| DEST-004 | Critical | Partial | WP-22 server-authoritative games deferred (product decision) | Player-only writes, immutable membership, dice bounds, stats/leaderboard bounds + 10 s throttle. | Any player can still write winner/pawnSteps/scores; bounded fake wins possible. | WP-22 before coins launch: game callables, Functions-only stats/leaderboards. |
| DEST-007 | High | Partial | Owner console action | Key removed from client (Secret Manager + callables); gitleaks config + pre-commit hook + CI job. | Key is still in git history. | O-1: rotate the key, set the secret, redeploy, revoke old key; optional git filter-repo. |
| DEST-008 | High | Partial | Owner console action | Message text kept out of push body until identity verification is on. | OneSignal.login(uid) has no JWT. | Implement/verify mintOneSignalJwt + client login with JWT; then O-5 Identity Verification. |
| DEST-011 | High | Partial | Owner console action; needs device testing | deleteAccount callable (recent sign-in), anonymises conversations, deletes data, push identity and Auth user; Settings flow with re-auth. | Cloudinary assets only queued; web deletion URL missing. | O-3 deploy functions; O-7 Cloudinary secret; O-11 web deletion URL; device-test deletion. |
| DEST-012 | High | Partial | Code follow-up; owner action | Enable Audio/Video toggles; both-users rule checked by caller, callee and sendCallPush. | No Function writes RTDB call_consent, so config/enforceCallConsent must stay off; a modified client can still write a ringing inbox entry (callee rejects it). admitIncoming fails open on lookup error. | Add call_consent mirror Function + backfill, then set enforceCallConsent=true; make admitIncoming fail closed. |
| DEST-013 | High | Partial | Owner console action | Client type/size/duration validation; no original upload on compression failure; signed-upload callable behind CLOUDINARY_ENABLED. | Unsigned presets still live; public delivery URLs. | O-7: restrict presets, authenticated delivery, store secret; switch client to signCloudinaryUpload. |
| DEST-015 | High | Partial | Owner console action | Usage strings, background modes, display name in Info.plist. | GoogleService-Info.plist missing; reversed client id via xcconfig not set. | O-9: flutterfire configure, GOOGLE_REVERSED_CLIENT_ID in xcconfig, APNs key. |
| DEST-018 | High | Partial | Code follow-up; needs device testing | PresenceService started from SessionService; offline on sign-out. | No RTDB presence -> Firestore mirror Function; a crash/kill leaves online:true. | Add presence mirror Function (onValueWritten presence/{uid}). |
| DEST-025 | High | Partial | Owner/Xcode action | Android channels created; in-app ringtone plays; push uses correct channel ids and incoming_call.caf. | incoming_call.caf not referenced in the Xcode project, so iOS call pushes use default sound. | O-9: add incoming_call.caf to Runner Copy Bundle Resources. |
| DEST-046 | Medium | Partial | Owner console action; code follow-up | Sender-only delete scrubs text/mediaUrl and preview; edit refreshes preview. | Cloudinary destroy only with CLOUDINARY_ENABLED; replyTo snapshots in later replies still hold deleted text. | O-7; decide whether to scrub reply snapshots server-side. |
| DEST-050 | Medium | Partial | Owner console action | getTurnCredentials callable path with cache; openrelay fallback kept. | Shared openrelay still used; relay-only off; TURN credential cache not cleared on sign-out. | O-10 provision TURN; then enable relayOnlyWhenNotMutual; clear cache in SessionService.signOut. |
| DEST-051 | Medium | Partial | Owner console action | Idempotent receipts, rate limits, trigger-based chat push, app id from config. | enforceAppCheck off until ENFORCE_APP_CHECK set. | O-6 App Check monitor then enforce; set ENFORCE_APP_CHECK=true. |
| DEST-052 | Medium | Partial | Owner console action | One 8+ policy, no trimming, mapped errors, verification email + router gate. | Rules do not gate discovery/chat on emailVerified. | O-6 password policy + enumeration protection; add emailVerified gating to rules. |
| DEST-054 | Medium | Partial | Owner console action | Release signing from gitignored key.properties; allowBackup=false; 100 MB cache cap. | Falls back to debug signing without a keystore. | O-8: create upload keystore + key.properties. |
| DEST-055 | Medium | Partial | Product decision deferred (WP-22) | Match list queries limited to playerUids. | Public matchmaking still pairs strangers; 'Play with your matches!' copy; no block/report in game chat. | WP-22 invite-from-chat flow and game-chat moderation, per owner decision. |
| DEST-059 | Medium | Partial | Owner console action | firestore.indexes.json covers traced composite queries; RTDB rooms .indexOn. | Not deployed; lobby listener fails with FAILED_PRECONDITION until built. | O-4 deploy indexes before shipping this client. |
| DEST-068 | Medium | Partial | Needs device testing; small code follow-up | Mark-read only in foreground, debounced, chunked under 500 writes. | 'delivered' written only when ChatScreen is open but backgrounded, not on push receipt or from chat list. | Write delivered from the push/foreground handler or chat list. |
| DEST-075 | Medium | Partial | Owner console action | Release signing separated so both SHAs can be registered. | No Android OAuth client for the actual applicationId. | O-8: final applicationId, register SHA-1/256, re-download google-services.json. |
| DEST-112 | Low | Partial | Owner console action | Client activates App Check; README runbook for key restrictions. | Keys unrestricted; App Check not enforced. | O-6. |
| DEST-127 | Low | Partial | WP-24 deferred | Dead providers removed; ConversationsRepository and DiscoveryFeed added. | UI files still call FirebaseFirestore.instance directly (29 uses in 21 files). | WP-24 repositories injected via Provider. |
| DEST-129 | Low | Open | WP-24 god-widget split deferred | Nothing (recommendation only). | carrom_game_screen ~1515 lines, chat_screen ~1739 lines, ludo_lobby_screen ~782 lines. | WP-24: extract ChatController and Carrom components, guarded by WP-29 tests. |
| DEST-130 | Low | Partial | Product decision (keep ML Kit); dev action | Image.network replaced by CachedNetworkImage; 8 unused packages removed from pubspec. | google_mlkit_translation kept but unused (DECISIONS); intl pinned ^0.18.1; pubspec.lock stale. | flutter pub get, commit pubspec.lock; decide on translation feature. |
| DEST-131 | Low | Partial | Needs flutter toolchain run | Strict lints, CI workflow, pre-commit hook, unit/widget tests written. | Tests never run; ~279 withOpacity, ~34 empty catches; CI format step continue-on-error. | Run flutter analyze/test; one-time dart format; tighten CI. |
| DEST-132 | Low | Open | WP-24 deferred; owner action | Functions use .env/params; single OneSignal app id constant. | No AppConfig or flavors; Cloudinary/TURN values hardcoded in client. | WP-24 AppConfig via --dart-define; O-13 dev/prod projects. |

### 9.1 Remaining issues by reason

- **Owner console action:** DEST-001, 002, 007, 008, 011, 013, 015, 025, 046, 050, 051, 052, 054, 059, 075, 112, plus parts of 012 and 132.
- **WP-22 server-authoritative games, deferred by product decision (until coins launch):** DEST-004, DEST-055.
- **WP-24 data layer / config / god-widget split, deferred:** DEST-127, DEST-129, DEST-132.
- **Product decision:** DEST-130. The ML Kit translation dependency is kept on purpose (DECISIONS).
- **Code follow-up found by re-audit (a Function is missing):** DEST-012 (call_consent mirror), DEST-018 (presence mirror).
- **Needs a Flutter toolchain or device run:** DEST-131. In practice every fix in section 8 also needs device validation (section 12).

### 9.2 Problems found by the re-audits that are still open

| Location | Problem | Next step |
|---|---|---|
| database.rules.json (enforceCallConsent branch) | Rules read `call_consent/{callee}/{caller}`, but no Function writes it. Turning the flag on would block every call. | Add the call_consent mirror Function and a backfill; only then set `config/enforceCallConsent=true`. |
| lib/services/presence_service.dart | No RTDB presence to Firestore mirror Function. After a crash or kill, `online:true` stays set in users and public_profiles. | Add an onValueWritten Function for `presence/{uid}`. |
| lib/services/call/call_service.dart admitIncoming | Fails open: if the consent or block lookup throws, the call rings. | Fail closed (reject) on lookup error. |
| storage.rules (chat_media) | isParticipant reads the conversation doc, which does not exist before the first message. A first photo or voice note on the Firebase Storage fallback path is denied. Cloudinary is the default, so this is latent. | Allow the two uids encoded in a deterministic conversation id, as the Firestore messages rule does. |
| lib/services/chat_service.dart deleteMessage | Delete-for-everyone does not scrub replyTo snapshots in later replies. | Server-side scrub, or accept as WhatsApp-like behaviour (product call). |
| ios/Runner.xcodeproj | incoming_call.caf is not in the Xcode project, so it is not bundled. | Add it to Copy Bundle Resources (O-9). |
| lib/services/call/webrtc/ice_servers.dart | TURN credentials are cached in static fields that are not cleared on sign-out. | Clear the cache in SessionService.signOut. |
| lib/screens/profile/profile_edit_screen.dart:238 | `docRef.snapshots()` is created in build, so every rebuild resubscribes. | Create the stream in initState. |
| lib/screens/home/home_controller.dart:188 | loadMore retries on every scroll notification after an error, with no backoff. | Add backoff or an error flag. |

Fixed during re-audit: `86cb1b8` bottom-nav tabs can be activated by screen readers again (a WP-27 regression). `b13eacf` reply snapshot text is capped at 2000 characters to match the rules.

---

## 10. Files and modules changed

`git diff --shortstat main..HEAD` (before this report): 209 files changed, 23848 insertions(+), 25085 deletions(-). Added 71, modified 112, deleted 26.

Commits on `fix/audit-remediation` (`git log main..HEAD`, oldest first, 34 before this report):

```
8400e2d Add audit report, fix plan and product decisions
b5c46ac WP-1: Security rules for Firestore, RTDB and Storage (DEST-001, DEST-004, DEST-047, DEST-048, DEST-059, DEST-113)
83f38b8 WP-2: Secret scanning and secrets runbook (DEST-007, DEST-112, DEST-051, DEST-008)
45deff1 WP-4: Auth, session lifecycle, 18+ gate and presence (DEST-005, DEST-008, DEST-009, DEST-010, DEST-018, DEST-030, DEST-052, DEST-053, DEST-074, DEST-078, DEST-102, DEST-111, DEST-124)
b93ba03 WP-6: Platform config, signing and notification channels (DEST-015, DEST-025, DEST-054, DEST-075, DEST-114)
d8c2c68 WP-8: Home tour keys per instance and first-run-only tour (DEST-017, DEST-057, DEST-098)
18f7477 WP-9: Call lifecycle, consent gate, busy and missed calls (DEST-012, DEST-019, DEST-020, DEST-022, DEST-023, DEST-026, DEST-048, DEST-049, DEST-050, DEST-071, DEST-072, DEST-073, DEST-133)
f24d9dc WP-12: Chat data model, deterministic ids and media validation (DEST-013, DEST-046, DEST-053, DEST-061, DEST-062, DEST-063, DEST-065, DEST-068, DEST-115, DEST-118, DEST-119, DEST-120, DEST-126)
896ea70 WP-17: Profile photo and avatar flow on My Profile (DEST-033, DEST-053, DEST-056, DEST-076, DEST-099, DEST-103, DEST-135)
faedf43 WP-19: Ludo turn sync, away grace and queue claims (DEST-036, DEST-037, DEST-038, DEST-039, DEST-040, DEST-086, DEST-087, DEST-088, DEST-089, DEST-090, DEST-092, DEST-110, DEST-121, DEST-122, DEST-123, DEST-125, DEST-136)
e596d16 WP-20: Carrom scoring, turn sync, forfeit and rematch (DEST-006, DEST-036, DEST-041, DEST-042, DEST-043, DEST-044, DEST-045, DEST-083, DEST-085, DEST-087, DEST-088, DEST-091, DEST-092, DEST-122)
9661a6e Wave 1: integration fixes
2b43765 WP-5: Block, report, blocked users, account deletion and settings links (DEST-003, DEST-011, DEST-017, DEST-034)
de35bc9 WP-3: Public profiles, paginated discovery and coarse location (DEST-002, DEST-010, DEST-028, DEST-056, DEST-064, DEST-080, DEST-081, DEST-134)
4612585 WP-10: Call screens follow the call phase and close on end (DEST-021, DEST-025, DEST-026, DEST-056, DEST-070, DEST-093)
98b4737 WP-21: Game list stats refresh and Love Physics cleanup (DEST-084, DEST-092, DEST-137)
f2d7265 WP-14: Chat list stream caching, retry and per-user state (DEST-056, DEST-094, DEST-103, DEST-108)
8c8a370 WP-16: Onboarding questionnaire fixes and completion hand-off (DEST-030, DEST-031, DEST-032, DEST-079, DEST-082, DEST-103, DEST-110)
c256555 Wave 2: integration fixes
261e055 WP-7+13: Chat screen consent toggles, safety, replies and media limits (DEST-003, DEST-012, DEST-014, DEST-016, DEST-035, DEST-047, DEST-056, DEST-065, DEST-067, DEST-068, DEST-069, DEST-073, DEST-094, DEST-109, DEST-113, DEST-116, DEST-117)
2eadb3d WP-11: App start-up, notification routing and App Check (DEST-018, DEST-024, DEST-027, DEST-053, DEST-058, DEST-066, DEST-097)
c703e31 WP-15: Cloud Functions push, cleanup, identity and media (DEST-003, DEST-008, DEST-012, DEST-013, DEST-022, DEST-025, DEST-046, DEST-049, DEST-050, DEST-051, DEST-065, DEST-066, DEST-111)
26cf1c1 WP-18: Zodiac compatibility chip and single astrology screen (DEST-029, DEST-056, DEST-077, DEST-096, DEST-100, DEST-110)
c79c707 WP-26: Main shell with persistent bottom nav; drawer and search removed (DEST-101, DEST-107)
a8227c5 WP-28: Game lobby queries match deployed indexes (DEST-095)
6bd6184 Wave 3: integration fixes
5f70749 WP-23: Security rules v2 (DEST-001, DEST-002, DEST-003, DEST-012, DEST-061)
5658909 WP-25: Dead code, unused deps and cached images (DEST-097, DEST-128, DEST-130)
dd30ba9 Wave 4: integration fixes
462108a WP-27: Theme, contrast & accessibility (DEST-104, DEST-105, DEST-106)
5ad3b55 WP-29: Tests, lint, CI (DEST-131)
33d6141 Wave 5: integration fixes
86cb1b8 Re-audit: bottom nav tabs activatable by screen readers
b13eacf Re-audit: cap reply snapshot text at 2000 chars to match rules
```

| Module / folder | Added | Modified | Deleted |
|---|---|---|---|
| `(app root files)` | 9 | 6 | 0 |
| `.githooks` | 1 | 0 | 0 |
| `.github` | 1 | 0 | 0 |
| `android/app` | 2 | 3 | 0 |
| `functions` | 12 | 2 | 0 |
| `functions/scripts` | 2 | 0 | 0 |
| `functions/test` | 1 | 0 | 0 |
| `ios/Runner` | 1 | 1 | 0 |
| `lib/bottom_navigation/managers` | 0 | 0 | 1 |
| `lib/core/config` | 1 | 0 | 0 |
| `lib/core/constants` | 0 | 1 | 0 |
| `lib/core/services` | 0 | 0 | 1 |
| `lib/core/theme` | 0 | 1 | 0 |
| `lib/core/utils` | 2 | 3 | 0 |
| `lib/feature/games` | 2 | 18 | 3 |
| `lib/features/onboarding` | 0 | 3 | 0 |
| `lib/main.dart` | 0 | 1 | 0 |
| `lib/managers` | 0 | 3 | 0 |
| `lib/models` | 1 | 4 | 0 |
| `lib/screens/astrology` | 1 | 3 | 9 |
| `lib/screens/auth` | 3 | 3 | 3 |
| `lib/screens/calls` | 1 | 3 | 0 |
| `lib/screens/chat` | 1 | 7 | 1 |
| `lib/screens/home` | 0 | 7 | 4 |
| `lib/screens/profile` | 0 | 10 | 0 |
| `lib/screens/questionnaire` | 0 | 6 | 0 |
| `lib/screens/settings` | 1 | 3 | 0 |
| `lib/screens/shell` | 1 | 0 | 0 |
| `lib/services` | 7 | 6 | 1 |
| `lib/services/_helpers` | 0 | 0 | 1 |
| `lib/services/call` | 1 | 5 | 0 |
| `lib/services/media` | 2 | 1 | 0 |
| `lib/services/navigation` | 1 | 0 | 0 |
| `lib/services/notification` | 0 | 4 | 1 |
| `lib/services/storage` | 0 | 3 | 0 |
| `lib/widgets` | 0 | 3 | 1 |
| `lib/widgets/voice` | 0 | 1 | 0 |
| `test` | 0 | 1 | 0 |
| `test/core` | 3 | 0 | 0 |
| `test/feature` | 2 | 0 | 0 |
| `test/helpers` | 1 | 0 | 0 |
| `test/models` | 2 | 0 | 0 |
| `test/rules` | 6 | 0 | 0 |
| `test/services` | 3 | 0 | 0 |

**Key new files.** Security and backend: `firestore.rules`, `database.rules.json`, `storage.rules`, `firestore.indexes.json`, `.gitleaks.toml`, `functions/{push,cleanup,identity,media,media_utils,account,moderation,profile_mirror,common,config,conversation_rules}.js`, `functions/scripts/{backfill_public_profiles,migrate_conversations}.js`. Client: `lib/services/{session_service,safety_service,account_deletion_service,conversations_repository,discovery_feed_service,location_service,profile_photo_service}.dart`, `lib/services/call/call_consent.dart`, `lib/services/media/{media_validator,media_url_policy}.dart`, `lib/services/navigation/pending_intent.dart`, `lib/screens/auth/{auth_router,age_gate_screen,verify_email_screen}.dart`, `lib/screens/shell/main_shell.dart`, `lib/screens/settings/blocked_users_screen.dart`, `lib/screens/chat/widgets/report_dialog.dart`, `lib/screens/calls/widgets/call_ui.dart`, `lib/feature/games/{carrom/carrom_rules,ludo/ludo_rules}.dart`. Tooling: `.github/workflows/ci.yml`, `.githooks/pre-commit`, `.pre-commit-config.yaml`, `analysis_options.yaml`.

**Deleted files (26, unreachable or replaced):** `lib/bottom_navigation/managers/firestore_manager.dart`, `lib/core/services/location_service.dart`, `lib/feature/games/ludo/ludo_provider.dart`, `lib/feature/games/ludo/main_screen.dart`, `lib/feature/games/ludo/models/ludo_models.dart`, `lib/screens/astrology/steps/review_screen.dart`, `lib/screens/astrology/steps/step_eight_screen.dart`, `lib/screens/astrology/steps/step_five_screen.dart`, `lib/screens/astrology/steps/step_four_screen.dart`, `lib/screens/astrology/steps/step_one_screen.dart`, `lib/screens/astrology/steps/step_seven_screen.dart`, `lib/screens/astrology/steps/step_six_screen.dart`, `lib/screens/astrology/steps/step_three_screen.dart`, `lib/screens/astrology/steps/step_two_screen.dart`, `lib/screens/auth/astrology_questionnaire_fragment.dart`, `lib/screens/auth/astrology_questionnaire_screen.dart`, `lib/screens/auth/astrology_view_model.dart`, `lib/screens/chat/widgets/chat_list_slidable_wrapper.dart`, `lib/screens/home/home_logic.dart`, `lib/screens/home/home_ui.dart`, `lib/screens/home/widgets/custom_drawer.dart`, `lib/screens/home/widgets/profile_bubble_grid_item.dart`, `lib/services/_helpers/batch_delete.dart`, `lib/services/database_service.dart`, `lib/services/notification/onesignal_helper.dart`, `lib/widgets/profile_completion_banner.dart`.

**Largest rewrites:** carrom_game_screen.dart, chat_screen.dart, home_screen.dart, main.dart, discovery_settings_screen.dart, ludo_game_service.dart, chat_service.dart, call_service.dart. Much of the deleted line count is commented-out legacy code (DEST-128).

---

## 11. Tests executed

**What actually ran:** `dart format --output=none` parse checks on every changed Dart file (0 parse errors), `node --check` on all Functions and rules-test JS files, JSON/YAML/plist/XML validation (`python3 -m json.tool`, Ruby YAML, `plutil -lint`, `xmllint`, `bash -n`), the Functions unit tests (`node --test test/` in `functions/`, 7/7 passed, re-run for this report), grep/script-based code review in five wave integration checks and two re-audits. **`flutter pub get`, `flutter analyze`, `flutter test`, `flutter build`, the Firebase rules emulator tests, gitleaks, and all device tests have NOT been run yet.**

Partial or ad-hoc checks (not a full run): `dart analyze` on `carrom_rules.dart` alone and a standalone Dart script of the Carrom rule cases (WP-20); analyzer runs in scratch copies with offline or stubbed packages (WP-3, WP-20, WP-29); a WCAG contrast-ratio script (WP-27); import-resolution and AppColors-member scripts.

Blockers: pub.dev packages could not be fetched (proxy), there is no Java runtime for the Firebase emulators, and gitleaks is not installed. `pubspec.lock` is stale: `firebase_app_check`, `url_launcher` and `http_parser` were added and 8 unused packages were removed.

**Tests written but never executed:**

| File | Covers |
|---|---|
| `test/widget_test.dart` | QuestionWidget controller/cursor survives rebuilds, late answers, List<dynamic> (DEST-031/032) |
| `test/core/age_policy_test.dart` | DOB parsing incl. ms/negative epoch, 18+ policy (DEST-010/064) |
| `test/core/compatibility_utils_test.dart` | Zodiac compatibility score (DEST-029) |
| `test/core/geohash_public_profile_test.dart` | Geohash and public-profile shape (DEST-002/081) |
| `test/models/user_model_test.dart` | UserModel parsing (DEST-064/079) |
| `test/models/chat_models_test.dart` | Conversation/ChatMessage models, previews, reply snapshots |
| `test/services/call_consent_test.dart` | Both-users call consent (DEST-012) |
| `test/services/call_service_test.dart` | Call phase / end reasons (DEST-019/023) |
| `test/services/media_validator_test.dart` | Media type/size/duration limits (DEST-013) |
| `test/feature/games/ludo/ludo_rules_test.dart` | Ludo legal moves (DEST-089) |
| `test/feature/games/carrom/carrom_rules_test.dart` | Carrom scoring (DEST-006) |
| `test/rules/firestore.test.js` | Firestore rules positive/negative cases (needs emulator; only `node --check` ran) |
| `test/rules/database.test.js` | RTDB inbox/rooms rules (needs emulator) |
| `test/rules/storage.test.js` | Storage rules (needs emulator) |

To run: `flutter pub get && flutter analyze && flutter test` in `flutter_webrtc_dating_app_v3/`; `npm --prefix test/rules install && npm --prefix test/rules run test:emulators` (needs Java). CI (`.github/workflows/ci.yml`) runs these on push, but it has never run.

---

## 12. Risks requiring manual validation

The v2 rules have never been compiled, and none of the Flutter code has been compiled. Treat the first `flutter analyze` and emulator run as the first real gate. Old app builds will be rejected by the v2 rules, so ship a minimum-version gate before deploying them.

### 12.1 Device test checklist (Android and iOS, two accounts, release build)

**Auth**

- [ ] Email signup end to end; 7-character password shows inline error; verify-email screen blocks until link opened.
- [ ] Login wrong password shows mapped message; Done key submits; password manager autofill.
- [ ] Airplane mode right after Sign Up, then retry with same email: signup completes (no orphan account).
- [ ] Logout then login as a different user on the same device: no previous user's pushes, filters, tour state or cached chats.
- [ ] Change password with two devices signed in: other device is signed out within about 1 hour.

**Google sign-in onboarding**

- [ ] New Google account: age gate, then questionnaire, avatar, post-signup; not visible in discovery until onboarding is complete.
- [ ] Returning Google user goes straight to Home; cancelling the picker shows no error.
- [ ] Android: Google sign-in works with the final applicationId and registered SHA-1 (O-8).

**Age gate**

- [ ] Under-18 DOB is blocked with a clear message; 18+ checkbox and Terms/Privacy links shown.
- [ ] Legacy account without DOB is asked for DOB on next launch and is excluded from the feed until then.

**Discovery**

- [ ] Feed shows only 18+ users ordered by recent activity; scrolling past 30 loads more.
- [ ] Other users' data contains no email, DOB, exact coordinates or tokens (inspect network / public_profiles).
- [ ] Filters per account; disabled while 'Apply filters' is off; discard-changes prompt.
- [ ] Online status clears within about 1 minute of killing the app (expected to FAIL until the presence mirror Function exists).
- [ ] Compatibility chip shows on cards; card tap opens quick sheet.

**Chat send / edit / delete**

- [ ] Send text, image, voice note; each renders; airplane-mode failure restores text.
- [ ] Edit own message: same bubble updates, shows 'edited', no new push.
- [ ] Delete for everyone: text and media gone, preview shows 'This message was deleted'.
- [ ] Reply shows quoted text; tap scrolls to original. Clear chat and delete chat (history stays hidden on reopen).
- [ ] Two users send simultaneously: unread badges correct; one conversation doc only.
- [ ] Typing indicator clears within 5 s after killing the app; read vs delivered ticks.

**Push for chat / call**

- [ ] Chat push for text, image, voice to foreground, background, killed receiver; each arrives once with correct preview.
- [ ] Muted chat: no push. First message from a stranger: silent channel. After a reply: normal channel.
- [ ] Tap chat push from killed state opens the right chat after splash; no push for the chat currently open.
- [ ] Call push while killed shows incoming call; iOS ringtone (needs incoming_call.caf bundled); missed-call push opens the chat.

**Calls**

- [ ] Audio and video both directions; names and avatars correct on both sides; duration starts at connect.
- [ ] Calls blocked until BOTH users enable that type in the chat menu; tooltip text shown.
- [ ] Decline: caller sees 'Declined'. No answer 45 s: 'No answer' + missed-call line in both chats.
- [ ] Busy: during A-B call, C calls A; A's call continues, C sees 'User is busy'.
- [ ] Caller cancels: callee screen closes within 2 s; no ghost call after callee restart.
- [ ] Background the app during a call and return; system back asks 'End call?'; kill callee mid-call ends caller within about 15 s; Wi-Fi toggle recovers.
- [ ] Deny mic on callee: callee screen closes, caller sees failed. Calls work behind restrictive NAT once TURN is provisioned (O-10).

**Block / report**

- [ ] Block from chat: success only after write; other side loses input and call buttons; both hidden from each other's discovery; incoming calls from the blocked user rejected.
- [ ] Report: doc appears in `reports` with reason and message ids; Blocked Users screen lists and unblocks.

**Account deletion**

- [ ] Settings > Delete Account with re-auth (password and Google): account removed, login fails afterwards.
- [ ] Other user's chat shows 'Deleted user' and input disabled; deleted user's public profile gone; push identity removed.

**Ludo**

- [ ] 2- and 4-player games; background 5 s (game continues, away banner) and over 60 s (skip / forfeit).
- [ ] Kill the turn holder: turn skipped within about 35 s. Bonus turn after a 6 resets the timer. Illegal pawns not offered.
- [ ] Two phones search simultaneously and land in one match. Chat over 100 messages shows latest. Back to Lobby goes to lobby.

**Carrom scoring**

- [ ] Own coin +1 and keeps turn; Queen +3 only when covered next shot; striker foul -1 (min 0) and own coin returns; win on clearing own coins.
- [ ] Waiting player cannot move striker; striker only on own baseline; boards match on small and large phones; guest sees own baseline at bottom.
- [ ] Back during play forfeits (opponent sees victory); rematch only when both agree; stats increase exactly once; sounds play.

**Rules deploy**

- [ ] Before deploy: run emulator suite (test/rules) green; export current console rules (O-2).
- [ ] Deploy rules, indexes, RTDB rules, storage (O-4) only after this client ships, backfill has run, and a min-version gate exists.
- [ ] After deploy: console Indexes tab shows all composite indexes Enabled; smoke-test chat, calls, games, profile edit, photo upload; keep `config/rules {legacyUsersRead: true}` as emergency switch.
- [ ] Keep RTDB `config/enforceCallConsent` OFF until the call_consent mirror Function is deployed.

**Release / platform**

- [ ] Release APK signed with the upload key (`./gradlew :app:signingReport`); no Developer Options; no email/uid/refreshToken in logcat.
- [ ] iOS: camera, mic, photos, location prompts show purpose strings; Google sign-in URL scheme works.
- [ ] TalkBack/VoiceOver: bottom-nav tabs, call controls, chat actions are labelled and activatable; large text.

### 12.2 Owner manual actions (from FIX_PLAN.md)

| ID | Action | Issues | Status |
|---|---|---|---|
| O-1 | Rotate the OneSignal REST API key; `firebase functions:secrets:set ONESIGNAL_REST_API_KEY`; redeploy; revoke the old key; optionally `git filter-repo` and force-push. | DEST-007 | Pending - do first |
| O-2 | Export current Firestore, RTDB and Storage rules from the console; if test mode, deploy v1 lockdown immediately. | DEST-001 | Pending |
| O-3 | Confirm Blaze plan; deploy functions (`firebase deploy --only functions`), copy `functions/.env.example` to `functions/.env`; set trigger region if database is not nam5/us-central1. | DEST-011/015/022/051 | Pending |
| O-4 | Deploy rules and indexes: `firebase deploy --only firestore:rules,firestore:indexes,database,storage` (after client ships, backfill, min-version gate). | DEST-001/059 | Pending |
| O-5 | Turn on OneSignal Identity Verification after the JWT function and client JWT login are live; register App Check providers and debug tokens. | DEST-008 | Pending |
| O-6 | Firebase App Check (monitor then enforce, then ENFORCE_APP_CHECK=true); restrict API keys; Auth abuse protection; 8+ password policy; email-enumeration protection. | DEST-051/112/052 | Pending |
| O-7 | Cloudinary: restrict/disable unsigned presets, authenticated delivery, API secret in Secret Manager; set CLOUDINARY_ENABLED. | DEST-013/046 | Pending |
| O-8 | Final applicationId; upload keystore + gitignored `android/key.properties`; register debug and release SHA-1/256; re-download google-services.json (and re-run flutterfire configure). | DEST-054/075 | Pending |
| O-9 | iOS: `flutterfire configure` (GoogleService-Info.plist), GOOGLE_REVERSED_CLIENT_ID in xcconfig, APNs key to OneSignal/Firebase, bundle id, add incoming_call.caf to Copy Bundle Resources, Podfile permission macros. | DEST-015/025 | Pending |
| O-10 | Provision TURN (coturn or paid) and give the secret to getTurnCredentials. | DEST-050 | Pending |
| O-11 | Publish Privacy Policy, Terms, Support and web account-deletion URLs (fill `lib/core/config/app_links.dart`); store age rating 17+/18+. | DEST-011/034/010 | Pending |
| O-12 | Firestore TTL policies on `ludo_queue.expiresAt` and `carrom_queue.expiresAt` (optionally push_receipts, rate_limits). | DEST-087 | Pending (scheduled sweep covers it meanwhile) |
| O-13 | Separate dev and prod Firebase projects for flavors. | DEST-132 | Pending (WP-24) |

Also needed from a developer or the owner: `flutter pub get` and commit `pubspec.lock`; run `node functions/scripts/backfill_public_profiles.js --apply` (service-account credentials); optionally run `functions/scripts/migrate_conversations.js` (use `--drop-legacy` only after old builds are gone); `git config core.hooksPath .githooks`.

