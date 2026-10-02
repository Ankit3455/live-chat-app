# Flutter Firebase Auth App (scaffold)

## What's included
- `pubspec.yaml`
- `lib/` with a simple Firebase Email/Password auth (login, signup, home)
- `README` with setup instructions

## Important notes BEFORE running
1. This scaffold **does not** include Android/iOS platform folders (to keep the zip small).
   After unzipping, open a terminal in the project folder and run:
   ```
   flutter create .
   ```
   This will generate `android/ios/web` folders required to build the app.
2. Create a Firebase project at https://console.firebase.google.com/
   - Add an Android app (package name `com.example.flutter_firebase_auth_app`) and download `google-services.json`
   - (Optional) Add an iOS app and download `GoogleService-Info.plist`
   - For web, use the FlutterFire CLI to generate `firebase_options.dart` (optional)
   - Place `google-services.json` into `android/app/` and `GoogleService-Info.plist` into `ios/Runner/`
3. From the project folder run:
   ```
   flutter pub get
   flutter run
   ```
4. If you plan to use Firebase on web or want generated firebase_options, run:
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

## Quick testing
- Create a new user from the Signup screen, then login using those credentials.

## Troubleshooting
- If Firebase initialization complains, ensure you added the platform config files and rebuilt the app.
