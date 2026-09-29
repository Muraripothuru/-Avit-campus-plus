# AVIT Campus+

A production-oriented campus super-app for **Aarupadai Veedu Institute of
Technology (AVIT)** — one app for students, security staff, hostel wardens and
administrators.

Built with Flutter (Dart 3.13), Material 3, and a clean layering of
`features → app → data → core`.

## Roles & capabilities

| Role | Capabilities |
| --- | --- |
| Student | Gate pass requests, visitor passes, transport routes, smart queue slots, campus map, library, cafeteria, hostel, emergency SOS, complaints, academics hub, fees |
| Security | Gate/visitor pass verification (QR scanner), movement log, incident reporting, vehicle checks, quick profile lookup |
| Warden | Approve/decline gate & visitor requests, late returns, hostel complaints, student profiles |
| Admin | Dashboard with charts, publish announcements & events, user role management, audit log |

Bottom navigation, drawer, FAB, snackbars and `setState`-driven interactions
are used throughout the shells.

## Getting started

```powershell
flutter pub get
flutter run                      # demo repositories (works offline)
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

### Demo sign-in

| Email | Role |
| --- | --- |
| `student@avit.ac.in` | Student |
| `security@avit.ac.in` | Security |
| `warden@avit.ac.in` | Warden |
| `admin@avit.ac.in` | Admin |

Password: `Avit@2026Demo`

Biometric unlock (Face/Touch/fingerprint) can be enabled from **Settings →
Biometric unlock** after the first sign-in.

## Configuration

* `API_BASE_URL` — when defined, the app talks to the real REST backend;
  otherwise it runs the built-in demo repositories with generated seed data.
* Tokens live only in platform secure storage (Keystore/Keychain) and every
  secure-storage operation is time-bounded (3s) so startup can never hang.

## Architecture

```
lib/
  main.dart            composition root, auth-guarded router
  app/                 AppDependencies, AppState, themes, AppScope
  core/                routes, constants, utils, security, services
  data/                models, remote + demo repositories
  widgets/             AVIT* design-system components
  shell/               app shell: AppBar, drawer, bottom nav, FAB
  features/            auth, home, dashboard, campus, safety,
                       staff, account, academics
```

Theme: **AVIT BlueFlow** — light + dark Material 3 (`AppTheme.light` /
`AppTheme.dark`), switched from Settings.

## Checks

```powershell
flutter analyze --no-pub
flutter test
```

The suite covers four layers (71 tests):

* `test/repositories_e2e_test.dart` — every repository end to end: OTP, QR
  pass lifecycles, validation errors, staff desks, admin publishing.
* `test/screens_smoke_test.dart` — every named route for its allowed role:
  builds, finishes loading, raises no exception.
* `test/flows_test.dart` — critical journeys driven by real taps: sign-in form,
  bottom navigation, complaint composer, sign-out confirmation, warden approval.
* `test/widget_test.dart` — boot, protected-route redirect, unknown-route
  fallback.

Both must be clean before a release build:

```powershell
flutter build apk --release
flutter build appbundle --release   # Play Store
flutter build ipa --release         # App Store (macOS host)
```

## Version

`1.0.0+1` (see `pubspec.yaml`).
