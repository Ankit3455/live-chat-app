# Destined

Destined is a Flutter dating app (Dart package `availchat`) for Android and iOS. Users sign up, build a profile with an avatar and a voice intro, find people nearby, chat in real time, make audio and video calls (WebRTC), and play Ludo and Carrom together. Astrology compatibility is worked out from zodiac signs and shown on profile cards.

| Area | Technology |
|---|---|
| Auth, data, presence | Firebase Auth, Cloud Firestore, Realtime Database |
| Server code | Cloud Functions for Firebase v2 (Node 20), in `functions/` |
| Push notifications | OneSignal. The app registers the device; Cloud Functions send the pushes |
| Media (photos, voice intros, chat media) | Cloudinary unsigned uploads (Firebase Storage is the fallback) |
| Calls | `flutter_webrtc`. Signalling goes through RTDB; ICE servers are listed in `lib/services/call/webrtc/ice_servers.dart` |
| Crash reporting | Firebase Crashlytics |

Product decisions are in `../DECISIONS.md`. The audit and fix plan are in `../AUDIT.md` and `../FIX_PLAN.md`.

## Repository layout

```
live-chat-app/                     git root
├── .gitleaks.toml                 secret-scanning rules
├── .pre-commit-config.yaml        pre-commit hooks (gitleaks and more)
└── flutter_webrtc_dating_app_v3/  this app
    ├── lib/                       Flutter source
    ├── functions/                 Cloud Functions (push sending)
    ├── android/ ios/              platform projects
    ├── firebase.json .firebaserc  Firebase CLI config
    └── test/
```

## Prerequisites

- Flutter SDK (stable) with Dart 3.x
- Node 20 and the Firebase CLI (`npm i -g firebase-tools`), then `firebase login`
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)
- Python 3 and `pre-commit` (`pip install pre-commit`), plus `gitleaks` v8.25 or newer for manual scans
- Access to the Firebase project, the OneSignal app and the Cloudinary account (ask the owner)

## First-time setup

```bash
cd live-chat-app
pre-commit install                    # every commit is now scanned for secrets

cd flutter_webrtc_dating_app_v3
flutter pub get
flutterfire configure                 # regenerates lib/firebase_options.dart and google-services.json
(cd functions && npm install)
flutter run
```

## Configuration

### Firebase

- The project id is set in `.firebaserc`. The client config lives in `lib/firebase_options.dart` and `android/app/google-services.json`, and iOS needs `ios/Runner/GoogleService-Info.plist`. All of these come from `flutterfire configure`. Do not edit them by hand.
- Turn on these products in the console: Email/Password auth and Google sign-in, Firestore, Realtime Database, Storage, Functions and Crashlytics.
- Security rules and indexes are kept in the repo and listed in `firebase.json`. To deploy them:
  `firebase deploy --only firestore:rules,firestore:indexes,database,storage`
- To deploy the functions: `firebase deploy --only functions`. The project must be on the **Blaze** plan, because the functions use Secret Manager and make outbound calls.
- Google sign-in on Android needs the debug and release SHA-1/SHA-256 fingerprints registered in the Firebase console. Download `google-services.json` again after you add them.

### OneSignal

- **App ID** (a public identifier): the client initialises OneSignal with it in `lib/services/notification/`. `functions/index.js` uses the same ID. If the ID changes, update both places.
- **REST API key** (a secret): it lives only in Secret Manager and is read by the functions through `defineSecret('ONESIGNAL_REST_API_KEY')`. Never put it in the app or in any file.
  ```bash
  firebase functions:secrets:set ONESIGNAL_REST_API_KEY   # paste the key when prompted
  firebase deploy --only functions
  ```
- For iOS push, upload the APNs auth key in OneSignal (Settings > Platforms).
- Turn on **Identity Verification** only after the JWT-minting function and the client `OneSignal.login(uid, jwt)` change are live (see Owner manual steps).

### Cloudinary

- The cloud name, unsigned upload presets and folders are in `lib/core/config/storage_config.dart`. The cloud name and preset names are not secrets. **The Cloudinary API secret must never be in the app.**
- Anyone who has the APK can use an unsigned preset, so lock down each preset in the Cloudinary console. Allow only the formats the app uses (images: jpg/png/webp up to 10 MB; voice: audio up to 2 minutes), set a maximum file size, and turn off public_id and overwrite overrides.
- If you add signed uploads or deletion later, the API secret goes in Secret Manager (`firebase functions:secrets:set CLOUDINARY_API_SECRET`) and only a Cloud Function may use it.

### WebRTC / TURN

`ice_servers.dart` lists public STUN servers and the free Open Relay TURN servers, which are not suitable for production. Provision your own TURN server (coturn or a paid provider). The TURN shared secret belongs in Secret Manager. Clients get short-lived credentials from a Cloud Function, and the secret is never compiled into the app.

### Android release signing

`android/app/build.gradle.kts` reads `android/key.properties`, which is gitignored. Without that file, release builds are signed with the debug key and cannot be published.

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Keep the keystore and its passwords in a password manager. Never commit them. `*.jks`, `*.keystore` and `key.properties` are already gitignored.

## Secrets handling

| Value | Secret? | Where it lives |
|---|---|---|
| Firebase API keys and app ids (`firebase_options.dart`, `google-services.json`) | No, they are public client identifiers | Committed. Protected by API-key restrictions and App Check |
| OneSignal App ID | No | Client config and `functions/index.js` |
| OneSignal REST API key | **Yes** | Secret Manager `ONESIGNAL_REST_API_KEY` |
| Cloudinary cloud name and unsigned preset names | No | `storage_config.dart` |
| Cloudinary API key and secret | **Yes** | Cloudinary console, plus Secret Manager if a function needs them |
| TURN shared secret | **Yes** | Secret Manager |
| Android upload keystore and passwords | **Yes** | `android/key.properties` and the `.jks` file, both gitignored and kept off-repo |
| Firebase service-account JSON | **Yes** | Never in the repo. Use `gcloud auth application-default login` locally |

Rules:

1. Never commit a secret, not even "temporarily" or in a commented-out line. Git history is permanent.
2. Server secrets go only into Secret Manager (`firebase functions:secrets:set NAME`), and the functions read them with `defineSecret`.
3. A Flutter app binary can be decompiled. Anything compiled into it is public. Do not hide secrets with `--dart-define` either, because those values end up in the binary too.
4. `pre-commit` runs gitleaks on every commit. If gitleaks blocks a commit, remove the secret. Do not bypass it with `--no-verify`. If a real secret was ever committed, rotate it (see below). Deleting the line is not enough.
5. Manual scans:
   ```bash
   gitleaks dir .      # working tree
   gitleaks git .      # full history
   ```
   `.gitleaks.toml` allowlists only the Firebase client-config files and the already-leaked OneSignal key in two historical commits. That second entry is valid only after the key is rotated.

### Key rotation

Rotate a key immediately if it was ever committed, pasted in chat or shown in a screenshot, if a person with access leaves, or on a regular schedule.

**OneSignal REST API key** (this one is required now, DEST-007: the old key is in git history)
1. In the OneSignal dashboard go to Settings > Keys & IDs and create a new REST API key.
2. Run `firebase functions:secrets:set ONESIGNAL_REST_API_KEY` and paste the new key.
3. Run `firebase deploy --only functions`. Functions pick up the latest secret version when they are deployed.
4. Send a test chat message between two accounts and confirm the push arrives.
5. Delete or revoke the old key in OneSignal, then confirm that a request made with the old key is rejected.
6. Clean up old secret versions: `firebase functions:secrets:prune`, or `firebase functions:secrets:destroy ONESIGNAL_REST_API_KEY@<old-version>`.
7. Optional: rewrite history with `git filter-repo --replace-text` and force-push every branch. Then every collaborator must re-clone, and you should remove the history allowlist block from `.gitleaks.toml`. Rotation is what actually removes the risk. Rewriting history only cleans up.

**Cloudinary API secret**: In the Cloudinary console go to Settings > API Keys, generate a new key pair, update Secret Manager if a function uses it, redeploy, then deactivate the old key.

**TURN shared secret**: Change `static-auth-secret` on the TURN server and update the Secret Manager value at the same time, then redeploy the credential function. Credentials that were already issued expire on their own TTL.

**Firebase API key** (if abused or left unrestricted): In the GCP console go to APIs & Services > Credentials, create a new key with the same restrictions, run `flutterfire configure` (or update the configs), ship a new build, then delete the old key once old builds are no longer supported.

**Android upload key** (if lost or leaked): Request an upload-key reset in Play Console > App integrity, then register the new SHA fingerprints in Firebase.

### API-key restriction and App Check (DEST-112, DEST-051)

1. **Restrict the Firebase API keys** in GCP Console > APIs & Services > Credentials:
   - Android key: Android apps only, using the package name and the debug and release SHA-1.
   - iOS key: iOS apps only, using the bundle id.
   - Web key: HTTP referrers, only if a web build ships.
   - API restrictions: allow only the APIs the app calls (Identity Toolkit, Secure Token, Firestore, Realtime Database, Firebase Installations, Cloud Storage, Crashlytics, FCM, Cloud Functions, App Check).
2. **Turn on App Check**: Play Integrity on Android, and App Attest with a DeviceCheck fallback on iOS.
   - Register the apps in the Firebase console, and add debug tokens for development devices and emulators.
   - Leave Firestore, RTDB, Storage and Functions in **monitor (unenforced)** mode until most traffic shows as verified in App Check metrics. Turning on enforcement first locks out older app versions.
   - Then enforce per product. On the server side, callable functions should set `enforceAppCheck: true`.
3. **Turn on Auth abuse protection**: reCAPTCHA Enterprise / SMS region policy, a password policy of 8 or more characters, and email-enumeration protection.

## Owner manual steps

These need console or account access and cannot be done in code. Full list: `../FIX_PLAN.md`, section "Owner / console checklist".

| # | Step | When |
|---|---|---|
| O-1 | Rotate the OneSignal REST key (steps above) and revoke the old one | **Now** |
| O-2 | Export the current Firestore, RTDB and Storage rules from the console. If they are in test mode, deploy the repo rules immediately | Now |
| O-3 | Confirm the project is on the Blaze plan | Before deploying functions |
| O-4 | `firebase deploy --only firestore:rules,firestore:indexes,database,storage` | After rules changes |
| O-5 | Turn on OneSignal Identity Verification, after the JWT function and client login change ship | Later |
| O-6 | Restrict API keys, roll out App Check (monitor mode first, then enforce), and turn on Auth abuse protection | Phase 1–2 |
| O-7 | Lock down the Cloudinary unsigned presets. Move the API secret to Secret Manager if it is needed | Phase 2 |
| O-8 | Pick the final Android applicationId (currently `com.example.*`), create the upload keystore and `key.properties`, register the SHA fingerprints, and download `google-services.json` again | Before release |
| O-9 | iOS: run `flutterfire configure` (adds `GoogleService-Info.plist`), upload the APNs key to OneSignal and Firebase, and set the bundle id | Before iOS release |
| O-10 | Provision a TURN server. Put its secret in Secret Manager | Phase 2 |
| O-11 | Publish the Privacy Policy, Terms, Support and web account-deletion URLs, and set the store age rating to 17+/18+ | Before release |
| O-12 | Set up Firestore TTL on `ludo_queue.expiresAt` and `carrom_queue.expiresAt` | Phase 2 |
| O-13 | Create separate dev and prod Firebase projects | Phase 3 |

## Development

```bash
dart format lib test
flutter analyze
flutter test
pre-commit run --all-files
```
