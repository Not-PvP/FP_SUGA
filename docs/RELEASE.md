# Release guide and submission checklist

## 1. Point the app at a real API

The app reads the API address at build time. Without it, it uses the emulator/localhost default.

```
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com
```

The backend must be reachable from the phone (see `backend/README.md`). The release manifest
already declares the `INTERNET` and `POST_NOTIFICATIONS` permissions.

## 2. Create a signing key (once, by one person)

```
keytool -genkey -v -keystore suga-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias suga
```

Put the file somewhere outside the repo (or in `android/`, where `*.jks` is git-ignored), then create
`android/key.properties` (also git-ignored):

```
storeFile=../suga-release.jks
storePassword=...
keyAlias=suga
keyPassword=...
```

Never commit the keystore or `key.properties`. Back the keystore up: an app signed with a lost key
cannot be updated. Without `key.properties`, the release build is signed with the debug key, which is
fine for class demos but not for publishing.

## 3. Build and check the APK

```
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`. Install it on a real phone
(`adb install -r app-release.apk`) and walk through:

- [ ] Launcher icon is the SUGA bulb and the name reads "SUGA"
- [ ] Splash shows the bulb on the dark background, then the app opens
- [ ] Areas and brownouts load from the real API (proves `INTERNET` works in release)
- [ ] Choose an area; Home shows its status
- [ ] Notification permission prompt appears; a reminder fires (set a short lead time)
- [ ] Airplane mode: cached brownouts show with an offline notice; Retry works after reconnecting
- [ ] Admin sign-in, add / edit / delete a brownout
- [ ] Rotate the phone and switch to dark/light mode: no layout breakage

If notifications or scheduled reminders fail only in release, the first suspect is code shrinking:
see `android/app/proguard-rules.pro`.

## 4. Version

Bump `version:` in `pubspec.yaml` (`1.0.0+1` = name+build number) before each new APK you hand out.

## 5. Final submission checklist

Project requirements (SE2142):

- [ ] At least 4 screens (Home, Areas, Scheduled, Area Details, Brownout Details, Settings, Admin)
- [ ] At least 3 reusable widgets (`lib/widgets/ui.dart`, `advisory_card.dart`, `status_badge.dart`, ...)
- [ ] State management with Provider
- [ ] REST API integration (Express backend) with CRUD
- [ ] Local notifications
- [ ] `flutter analyze` reports no issues
- [ ] Release APK built, with the custom launcher icon and splash screen
- [ ] README with setup instructions and screenshots (`README.md`)
- [ ] Flutter DevTools debugging/performance case documented (`docs/devtools-debugging.md`)

GitHub:

- [ ] All issues closed or explained, project board up to date
- [ ] At least 3 pull requests reviewed (comments or approval) by the other member
- [ ] Commits from both members on `main`
- [ ] `main` builds from a clean clone
- [ ] No secrets in the repo (`.env`, keystore, `key.properties`)
- [ ] Release APK attached to a GitHub release (tag `v1.0.0`) or submitted as instructed
