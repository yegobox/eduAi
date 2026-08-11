# EduAI

An offline-first Flutter **desktop** app that is the foundation for *education with AI*.
It ships a production-shaped authentication layer:

- **Supabase** email/password auth (online)
- **Firebase phone (SMS)** verification (online, mobile/web)
- **Offline login** — unlock the app with a device PIN when there is no internet
- **Riverpod** for state management, in a clean **feature-first** architecture

> Primary target is **Windows desktop**. Android and Web are enabled too
> (Firebase phone auth only works on Android/iOS/Web — see notes below).

---

## Architecture

Feature-first clean architecture. Each feature owns three layers; `core/` holds
cross-cutting infrastructure. Nothing in `domain/` or `presentation/` imports an
SDK type — those live behind data sources and are mapped to plain entities.

```
lib/
├── main.dart                     # async bootstrap → ProviderScope overrides
├── app/
│   └── app.dart                  # MaterialApp.router
├── core/
│   ├── bootstrap/                # Supabase + Firebase init (defensive)
│   ├── config/                   # env-driven AppConfig + DI providers
│   ├── error/                    # Failure hierarchy + Result<T>
│   ├── logging/                  # AppLogger
│   ├── network/                  # ConnectivityService + providers
│   ├── router/                   # go_router with auth redirects
│   ├── security/                 # PinHasher (PBKDF2-HMAC-SHA256)
│   ├── storage/                  # SecureStorage (OS keychain wrapper)
│   └── theme/                    # Material 3 theme
└── features/
    ├── auth/
    │   ├── domain/               # AppUser, AuthSession, AuthRepository (interface)
    │   ├── data/                 # Supabase + Firebase + offline data sources, repo impl
    │   └── application/          # Riverpod controllers + state (AuthController, …)
    │   └── presentation/         # screens + widgets
    ├── schools/                  # schools / classes / memberships (join & learn)
    │   ├── domain/               # School, SchoolClass, Membership, SchoolsRepository
    │   ├── data/                 # Supabase remote source + offline cache, repo impl
    │   ├── application/          # providers + SchoolsActionController
    │   └── presentation/         # list, detail, join/create dialogs
    └── home/
        └── presentation/         # signed-in shell (where AI features grow)
```

### The dependency rule

`presentation → application → domain ← data`

Presentation talks to Riverpod controllers; controllers call the
`AuthRepository` interface; the repository implementation orchestrates the data
sources. Swap any layer (e.g. a fake repository in tests) via a provider
override.

---

## How offline login works

1. On a successful **online** sign-in (Supabase or Firebase phone), the app
   caches a small record in the **OS-encrypted secure store**
   (`flutter_secure_storage`): the user profile, the provider, and the last
   refresh token. This record **never leaves the device** and is never synced.
2. The user sets an **offline PIN** (Home → menu → *Set/change offline PIN*).
   Only a random salt and a **PBKDF2-HMAC-SHA256** hash of the PIN are stored —
   never the PIN itself.
3. When the app launches **without a live session** but a cached credential
   exists, the router shows the **Offline unlock** screen. Entering the correct
   PIN restores the cached session (`AuthSession.isOffline == true`).
4. When connectivity returns, Supabase silently refreshes the real session.

Secrets (PIN hash, tokens) stay in the keychain by design — see the discussion
in the code comments for why a syncing DB (e.g. Ditto) is the wrong place for
them. Ditto/Drift/Isar are the right tools for the **data** layer (lessons,
progress) and can be added behind the existing repository seam later.

---

## Getting started

### 1. Prerequisites
- Flutter 3.44+ (`flutter --version`)
- A Supabase project (URL + publishable/anon key)
- (Optional, for SMS) a Firebase project with Phone auth enabled

### 2. Configure secrets
Copy the template and fill in your values (this file is git-ignored):

```bash
cp env.example.json env.json
```

### 2b. Create the database schema
Run the SQL in the Supabase dashboard (**SQL Editor → New query**), or with the
Supabase CLI:

```bash
# in the Supabase SQL editor, paste & run:
#   supabase/migrations/0001_schools.sql   (tables + RLS)
#   supabase/seed.sql                       (optional demo schools/classes)
```

This creates `schools`, `classes` and `memberships` with Row Level Security so
the publishable/anon key is safe in the client: anyone signed in can read the
catalog, but a user can only see and change **their own** memberships.

### 3. Run

Windows desktop:
```bash
flutter run -d windows --dart-define-from-file=env.json
```

Android (real SMS works here):
```bash
flutter run -d android --dart-define-from-file=env.json
```

Web:
```bash
flutter run -d chrome --dart-define-from-file=env.json
```

> The app **boots even without `env.json`** — online auth is simply disabled
> and you can still exercise the UI and offline flows.

### 4. Test & analyze
```bash
flutter analyze
flutter test
```

## Testing

The suite is designed to catch regressions before they reach a child's device.
Everything runs headless via `flutter test` (no device, no network, no Supabase)
because the flow tests swap the data layer for in-memory fakes at the repository
boundary — the **real** app (router, theme, screens, Riverpod controllers) is
what gets exercised.

| Layer | Files | What it guards |
|-------|-------|----------------|
| Unit | `test/pin_hasher_test.dart`, `test/result_test.dart` | PIN hashing, Result type |
| Widget / layout | `test/*_layout_test.dart` | Every screen lays out with the **real theme** at mobile + desktop (catches overflow / unbounded-constraint crashes) |
| End-to-end flows | `test/auth_flow_test.dart`, `test/schools_flow_test.dart`, `test/rendering_smoke_test.dart` | Full journeys: sign-in (success + failure), offline PIN set / unlock, browse → join a class → see it on home, join-by-code |

Run everything:
```bash
flutter test
```

`test/support/` holds the fakes (`FakeAuthRepository`, `FakeSchoolsRepository`)
and `pumpApp()`, which boots `EduAiApp` with those fakes injected via
`ProviderScope` overrides. Add a new journey by writing another `*_flow_test.dart`.

CI (`.github/workflows/ci.yml`) runs `flutter analyze` + `flutter test` on every
push and pull request.

> Note: these tests give high confidence in the critical paths, but no suite
> proves an app is bug-free. Keep adding a test for every bug found and every
> new flow.

---

## Firebase phone (SMS) setup

Firebase phone auth is **not supported on desktop** (Windows/macOS/Linux). It
runs on **Android, iOS and Web**. To enable it:

1. `dart pub global activate flutterfire_cli`
2. `flutterfire configure` (generates platform config + `firebase_options.dart`)
3. In the Firebase console, enable **Authentication → Phone**.
4. On Android, add your SHA-1/SHA-256 signing keys.

The code path is already wired (`FirebasePhoneAuthDataSource`); it activates
automatically once Firebase initialises on a supported platform. On desktop the
SMS button surfaces a clear "not available here" message and falls back to email
/ offline PIN.

---

## Schools, classes & joining

- **Browse** the catalog (`Home → Browse schools`), open a school to see its
  **classes**, and **Join** a school or a specific class.
- **Join by code** — teachers share a `join_code`; students enter it to enrol
  without browsing.
- **Create** a school or class — the creator is enrolled as `owner`/`teacher`,
  so the flow is testable end-to-end without touching the database by hand.
- **Offline** — the last-fetched catalog and your memberships are cached
  (`shared_preferences`), so an offline-unlocked user still sees them. Writes
  (join/create) require a connection and surface a clear message otherwise.

Data model:

```
schools (id, name, description, join_code, created_by)
   └── classes (id, school_id, name, grade, join_code, created_by)
memberships (id, user_id, school_id, class_id?, role)   -- role: student|teacher|owner
```

> `class_id` is null for a school-level membership. RLS restricts membership
> rows to `user_id = auth.uid()`. For production, tighten `classes` inserts to
> school owners/teachers (currently any authenticated user, for demo ease).

## What's intentionally deferred

- **Offline-first data sync** (Ditto/Drift/Isar) — the `AuthRepository` pattern
  is the template; add a `LessonsRepository` the same way.
- **AI features** — the home shell has placeholder cards marking where the
  tutor / lessons / progress features attach.
- **Localization, deep theming, analytics/crash reporting** — `AppLogger` is the
  seam for the last one.
