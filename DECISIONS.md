# Destined — product decisions for the audit fixes (2026-10-04)

Source: owner answers + owner's own notes ("all aplication implimaentation.txt", "Coin based features list.txt").

## Answered by owner
- DEST-003 Block/Report: Block hides both users from each other in discovery, chat and calls (both directions). Report is saved to a `reports` collection; owner reviews in Firebase console. No email.
- DEST-011 Account deletion: delete profile, photos, auth account, push identity. Messages already sent to others stay but show sender as "Deleted user" (anonymise). No grace period.
- DEST-006 Carrom scoring: each player owns a colour (host = white, guest = black). Own coin pocketed = 1 point; Queen = 3 points, only counts if covered by pocketing an own coin on the next shot (otherwise Queen returns to centre); striker pocketed = foul, -1 point (min 0) and one own coin returns to centre if any pocketed. First to clear all own coins (and Queen resolved) wins. Pocketing a coin keeps the turn; otherwise the turn passes.
- DEST-055 / DEST-004 / DEST-121 Games: keep public matchmaking + lobbies as built; fix sync/turn/state bugs client-side. Server-authoritative games (WP-22) deferred until coins launch. No coins/points awards from Ludo yet.

## From owner's notes (already decided by owner)
- DEST-012 Calls: unknown users cannot call. Chat screen has "Enable Audio" / "Enable Video" toggles per user; a call type is allowed only when BOTH users enabled it. Tooltip: "Calls are possible only when both users enable call permission."
- DEST-101 Home: remove search icon and hamburger menu/drawer from Home; move its items into Profile and Settings (Help & Support, Astrology profile, Sign out -> Settings/Profile).
- DEST-098 Home tour shows only the first time; Skip ends it permanently.
- DEST-029 / DEST-100 Astrology: DOB -> zodiac -> compatibility score shown as chip on other users' profile card; remove extra astrology screens that do not feed the score. Tooltip: "Astrology compatibility is calculated from zodiac signs."
- New-chat notifications (status 'new', receiver has not replied) are silent (low-priority channel); active chats normal.
- DEST-097 Push: standardise on OneSignal (server-side). Remove dead FCM token code only if unused.
- Change Avatar lives on My Profile (working), removed from Edit Profile.
- Coin/premium features: NOT built in this pass.

## Safe defaults chosen (reversible, standard practice)
- DEST-002 Public profile fields: name, age (computed, not DOB), city / approximate distance (rounded to ~5 km, never coordinates), photos/avatar, bio, interests, zodiac sign, gender, voice intro. Private: email, exact DOB, birth time/place, GPS coordinates, push tokens, settings.
- DEST-010 18+: DOB required at signup; under-18 blocked with a clear message; checkbox "I confirm I am 18 or older" + Terms/Privacy links. Existing accounts without DOB are asked for DOB on next launch (profile completion gate).
- DEST-013 Keep Cloudinary; enforce client-side type/size limits (images <= 10 MB jpg/png/webp, voice <= 2 min). Signed uploads need owner's Cloudinary secret -> owner manual action; code path via Cloud Function prepared only if trivial, else documented.
- DEST-019 Busy: auto-reject incoming call with status 'busy'; caller sees "User is busy".
- DEST-073 Missed/declined calls: caller sees "No answer"/"Declined"; receiver gets a missed-call notification; a small system line in chat ("Missed audio call") is OK.
- DEST-028 Discovery: default filters = owner's saved prefs or none; ordering = most recently active; paginated (page of 30).
- DEST-037 Ludo: 60 s away grace, then that player is skipped; 2-player game forfeits after 60 s away (not instantly).
- DEST-045 Carrom: leaving = forfeit (opponent wins); rematch only if both agree.
- DEST-050 TURN: keep config-driven ICE servers; owner provisions TURN (manual). Remove nothing that currently works.
- DEST-076 Keep DiceBear avataaars; fix answer->avatar mapping only.
- DEST-084: Love Physics removed on 2026-10-05 at the owner's request.
- DEST-128 / DEST-130: do NOT delete features (ProfileViewScreen, leaderboard/stats widgets, ML Kit translation). Wire up only if trivial and safe; otherwise leave and list as remaining.
- DEST-096 Keep animations; only fix jank (dispose/RepaintBoundary), no redesign.
- DEST-118 Delete chat = WhatsApp-style: history before the delete time stays hidden for that user if the conversation reopens.
- DEST-124 Splash: keep current behaviour.
- DEST-134 English only for now (no l10n framework).
- DEST-034 Settings: ship tiles that work (Account, Discovery, Change password, Notifications toggle, Blocked users, Privacy Policy/Terms/Support via URLs in one config constant, Delete account, Sign out). Remove developer/debug tiles from release builds. Legal URLs = placeholders in config; owner must fill (manual).
