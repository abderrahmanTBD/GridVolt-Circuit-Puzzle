# Publishing GridVolt to Google Play

Everything in the repo is ready; the steps below need your accounts.

## 1. Crash reporting (Sentry) — one-time

1. Create a free account at [sentry.io](https://sentry.io) and a new project
   of type **Flutter**. Copy its **DSN** (Settings → Client Keys).
2. In the project, open **Settings → Security & Privacy** and turn on
   **Prevent Storing of IP Addresses** and **Data Scrubber**. The privacy
   policy states that IP addresses are not stored, so this setting is
   required.
3. Optionally set **Data Retention** to 90 days or less.

The DSN is not secret (it's embedded in every build), but it's kept out of the
repo so forks don't report into your project. Without it, crash reporting is
simply off.

## 2. Build the release bundle

```bash
flutter build appbundle --release --dart-define=SENTRY_DSN=https://<key>@<org>.ingest.sentry.io/<id>
```

Output: `build/app/outputs/bundle/release/app-release.aab`, signed with the
upload key. Bump `version:` in `pubspec.yaml` (`1.0.1+2` etc.) before every
upload; the number after `+` must always increase.

## 3. The upload key — back it up now

| File | What it is |
| --- | --- |
| `C:\Users\D Tech PLUs\gridvolt-upload-keystore.jks` | The upload key (alias `upload`) |
| `android/key.properties` | Its password and location (git-ignored) |

Copy **both** to a password manager or an offline drive. With Play App
Signing (the default), Google holds the real app-signing key, so a lost upload
key can be reset through Play support. That takes days, though, and blocks
updates until then.

Upload certificate SHA-256:
`29:E7:B4:97:A5:44:02:4B:1F:F3:57:6D:30:5D:2C:1D:9C:CC:17:8A:19:1B:1D:A6:62:7A:5B:A6:C7:B3:0B:70`

## 4. Play Console

1. **Create app**: name *GridVolt: Circuit Puzzle*, type *Game*, *Free*.
   Category: **Puzzle**.
2. **App signing**: accept Play App Signing when you upload the first bundle.
3. **Testing first.** New personal developer accounts must run a **closed
   test with at least 12 testers for 14 days** before production access is
   granted. Upload the `.aab` to a closed testing track and invite testers.
4. **Store listing** (everything is in `docs/store/`):
   - App icon: `docs/store/icon_512.png`
   - Feature graphic: `docs/store/feature_graphic.png` (1024×500)
   - Phone screenshots: `docs/store/screenshots/*.png` (1080×1920)
   - Short description (80 chars max), for example:
     *Drag neon circuit pieces, clear lines, trigger battery chain reactions.*
5. **Privacy policy URL**:
   `https://github.com/abderrahmanTBD/GridVolt-Circuit-Puzzle/blob/main/docs/privacy-policy.md`
6. **App content** questionnaires:
   - Ads: **No**.
   - Content rating (IARC): no violence, no user interaction or sharing, no
     purchases. This should rate **Everyone / PEGI 3**.
   - Target audience: **13+** is simplest. Choosing under-13 adds Families
     policy requirements.
   - Data safety, matching the privacy policy:

     | Question | Answer |
     | --- | --- |
     | Collects or shares user data? | **Yes**, collects |
     | Data types | **App info and performance → Crash logs, Diagnostics**; **Device or other IDs** (random install ID) |
     | Shared with third parties? | **No** (Sentry is a service provider processing on your behalf) |
     | Processed ephemerally? | No |
     | Required or optional? | Required |
     | Purpose | **Analytics** (app stability) |
     | Encrypted in transit? | **Yes** (HTTPS) |
     | Users can request deletion? | **Yes**, by email |

## Re-generating assets

```bash
flutter test tool/branding        # icon, adaptive icon, splash, store icon, feature graphic
dart run flutter_launcher_icons   # writes Android/iOS launcher icons
dart run flutter_native_splash:create
flutter test tool/readme_media    # README + Play Store screenshots
```
