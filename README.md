# EduAI

[![CI](https://github.com/yegobox/eduAi/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/yegobox/eduAi/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/yegobox/eduAi/branch/main/graph/badge.svg)](https://codecov.io/gh/yegobox/eduAi)
[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)](https://flutter.dev)

An offline-first Flutter app for *education with AI*, built for Rwandan
students, their parents and their schools. One codebase renders native-feeling
chrome on **iOS, Android, macOS and Windows**.

- **Four roles, four shells** — Student (Home / Tutor / Workbook / Lessons /
  Progress), Parent (Overview / Reports / Messages / Plan), Teacher (Classes /
  Progress) and School admin (License / People / Invoices / Usage). Three are
  chosen at sign-up; teacher is granted only by redeeming a school's code.
- **Two ways to pay** — a school buys per-seat licences after a 30-day trial, or
  a parent with no school subscribes per child. See
  [Who pays, and for what](#who-pays-and-for-what).
- **Stylus-first** — a pressure-sensitive ink canvas powers the Workbook, the
  Tutor scratchpad and lesson annotation.
- **Offline-first** — bundled REB-aligned lessons, cached catalogs, and a device
  PIN that unlocks the app with no internet.
- **Mobile Money** — licences, family plans and top-ups pay through the same MTN
  gateway Flipper uses.
- **Supabase** email/password auth, **Firebase phone (SMS)** verification.
- **Riverpod** state management in a **feature-first** architecture.

---

## Code quality

The badges above are live. CI runs on every push and pull request
(`.github/workflows/ci.yml`):

```
flutter analyze          # must be clean — no errors, warnings or infos
flutter test --coverage  # full suite, headless
→ upload coverage/lcov.info to Codecov
```

Coverage trend, per-file detail and the diff for any PR are on
[the Codecov dashboard](https://codecov.io/gh/yegobox/eduAi). Thresholds live in
[`codecov.yml`](codecov.yml):

| Check | Target | Enforcing? |
|---|---|---|
| Project total | previous coverage, −2% tolerance | No — reports the trend |
| Patch (lines the PR touches) | 60% | No — comments, does not block |

Both are `informational: true`, so a coverage drop **comments but never fails a
build**. Flip that in `codecov.yml` when you want it to gate merges.

Locally:

```bash
flutter analyze
flutter test                      # fast: no coverage instrumentation
flutter test --coverage           # writes coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

`lib/main.dart` and generated files are excluded from coverage — they are wiring,
not logic. The Supabase- and Firebase-bound data sources are deliberately thin
and largely uncovered: they need a live backend rather than a unit test, so the
logic that matters sits behind them in repositories and entities, which are
covered.

---

## Architecture

Feature-first clean architecture. Each feature owns four layers; `core/` holds
cross-cutting infrastructure. Nothing in `domain/` or `presentation/` imports an
SDK type — those live behind data sources and are mapped to plain entities.

```
lib/
├── main.dart                     # async bootstrap → ProviderScope overrides
├── app/
│   ├── app.dart                  # MaterialApp.router, themed per platform
│   └── shell/                    # adaptive nav chrome + more menu + detail scaffold
├── core/
│   ├── bootstrap/                # Supabase + Firebase init (defensive)
│   ├── config/                   # env-driven AppConfig + DI providers
│   ├── error/                    # Failure hierarchy, Result<T>, Postgrest classifiers
│   ├── format/                   # dates, currency, relative times
│   ├── ink/                      # pressure-sensitive stroke model + canvas
│   ├── logging/                  # AppLogger
│   ├── network/                  # ConnectivityService + providers
│   ├── platform/                 # AppPlatformStyle (ios/android/macos/windows)
│   ├── router/                   # go_router: one StatefulShellRoute per role
│   ├── security/                 # PinHasher (PBKDF2-HMAC-SHA256)
│   ├── state/                    # language preference
│   ├── storage/                  # SecureStorage + KeyValueCache
│   ├── theme/                    # AppTokens (ThemeExtension) + AppTheme
│   └── widgets/                  # the shared UI kit (card, badge, ring, …)
└── features/
    ├── auth/                     # identity, offline PIN, AppRole
    ├── access/                   # entitlement + the purchases that grant it
    ├── linking/                  # parent ↔ student links and their invites
    ├── schools/                  # schools / classes / memberships
    ├── teacher/                  # a teacher's classes and their students' progress
    ├── tutor/                    # AI chat with blocks + pen scratchpad
    ├── workbook/                 # 3-page stylus notebook + AI handwriting check
    ├── lessons/                  # REB catalog, offline download, reader
    ├── progress/                 # mastery rings, streak, exam readiness
    ├── parent/                   # children, reports, teacher thread, plan
    ├── billing/                  # price list, roster, payment ledger, usage
    └── payments/                 # Mobile Money (payNow + request-to-pay polling)
```

**The dependency rule:** `presentation → application → domain ← data`.
Presentation talks to Riverpod controllers; controllers call repository
*interfaces*; implementations orchestrate data sources. Swap any layer (a fake
repository in tests) with a provider override.

### Platform adaptation

One shared widget tree per feature. Only the **navigation chrome** and a few
tokens change per platform, driven by `appPlatformStyleProvider`:

| | Chrome | Card radius | Control radius | H1 |
|---|---|---|---|---|
| iOS | large title + bottom tab bar | 20 | 14 | 30 |
| Android | AppBar + M3 `NavigationBar` | 16 | 100 (pill) | 26 |
| macOS | toolbar with centred segmented tabs | 12 | 8 | 22 |
| Windows | app strip + Fluent pivot tabs | 8 | 5 | 20 |

Cards carry a soft shadow on mobile and a flat 1px border on desktop. Fonts are
deliberately not set, so each platform uses its own system face. Colours, radii
and the type scale live in `AppTokens`, a `ThemeExtension` read through
`AppTokens.read(context)` — no widget imports a palette file.

### Roles

The four roles are **different signed-in identities**, not a runtime toggle:
`AppUser.role` decides which `StatefulShellRoute` the router lands on, and a deep
link into another role's shell bounces home. A debug-only "View as" item in the
More menu reaches the other shells without minting four accounts.

Role lives server-side on `public.profiles`, never in Supabase user metadata — a
client can write its own metadata, and it stays writable afterwards. A trigger
validates the requested role against an allowlist at sign-up; a second trigger
refuses any later change carrying an end-user JWT, so converting an account is a
support action. `ProfileRemoteDataSource.fetchRole` returning null means *"keep
what you already believe"*, never "student": a dropped request must not demote a
director to the student shell.

---

## Who pays, and for what

Two revenue lines. A student is entitled by **either**.

### A. A school buys seats (B2B)

```
sign up as "I run a school"        → profiles.role = 'school_admin'
        ↓
Licence tab: "Create your school"  → schools row
        ↓  (trigger: start_school_trial)
school_licenses: trialing, 30 days, 50-seat cap
        ↓
share class join codes → students enrol → each consumes a seat
        ↓
Pay with MoMo (server-priced quote) → settle_school_license()
        ↓
school_licenses: active, current_period_end = +30 days
```

- Creating a school **starts the trial clock**. A school can never exist in an
  unknown billing state — the licence row is created by trigger.
- Only a `school_admin` can insert a school, enforced in RLS
  (`schools_insert_self` checks `my_role()`), not just by hiding a button.
- Seats are **counted from the roster**, not typed in. An admin controls how many
  they *buy*; `school_seats_used()` counts enrolled students; the bill is the
  larger of the two. A school cannot enrol 300 students against 50 seats.
- Paying during a trial **adds a period** rather than forfeiting the days left.

### B. A parent subscribes directly (B2C)

```
sign up as "I am a parent" → link a child → no school licence covers them?
        ↓
Plan tab: family plan, priced per linked child → settle_parent_subscription()
```

A parent **never creates a school**. If their child's school has a licence,
`access_state()` reports `source: school_license` and the Plan tab leads with
*"Included in {school}'s EduAI plan"* — the school-paid check runs **before** the
parent's own subscription, so a parent is never asked to pay for access somebody
already bought.

### The entitlement gate

One server function, `access_state()`, answers *"may this account use EduAI, and
until when?"* in a single round trip. The UI reads its result through
`accessSnapshotProvider`, so no two screens can disagree.

| status | meaning |
|---|---|
| `entitled` | paid and current |
| `trialing` | inside the trial window — full access, on a clock |
| `needs_payment` | there is something to bill and it has not been paid |
| `needs_setup` | nothing to bill yet (no school / no child linked) |

**What locks, and what never does.** Only the surfaces that cost money to run
stop: the AI Tutor (`AccessGate`) and the workbook's AI check. Lessons, the
canvas, saved pages and a student's own progress stay open when a licence
lapses. Holding a child's completed work hostage over their school's invoice is
not a collections strategy.

**Failure modes fail closed.** An unrecognised status parses as `unknown`, not
`entitled`, so a server that grows a new state cannot hand out access. A cached
entitlement has its status recomputed against the clock, so a month offline past
renewal is not a free month. `unknown` counts as *allowed* only for the moment
before the first response — the server rejects unentitled work anyway, and
flashing a paywall at every cold start would punish paying users for latency.

**Builds with no Supabase** (design review, widget tests) cannot enforce
anything, so `AccessState.unconfigured()` opens the app up with
`enforced: false`. That flag stops the UI claiming a plan was paid for. A
Supabase project that is *missing the billing schema* is reported separately and
loudly (`AccessState.schemaMissing()`), because otherwise every account silently
reads back as an unpaid student and nobody is charged.

### Prices live on the server

`plan_tiers` and `parent_plans` are tables, and every `settle_*` function
**recomputes the amount** before granting anything. The client asks for a quote,
shows exactly it, pays exactly it. A modified build cannot buy the District tier
for 1 RWF; an under-reported settlement is recorded as `disputed` and activates
nothing, so the money stays traceable.

### Testing a payment without paying a real licence

Testing needs real money to move — MTN prompts a real handset and settles a real
reference — and a licence starts at 7,500 RWF. Non-production projects can charge
a token amount:

```sql
-- Supabase SQL editor (service role; a signed-in client is refused)
select public.enable_test_pricing(100, 24);   -- 100 RWF for the next 24 hours
select public.disable_test_pricing();
```

The override lives in the **quote**, not the client, and that is the whole
design: `settle_*` recomputes from the same quote function and records anything
short of it as `disputed`, so a client that simply paid 100 RWF against a 7,500
RWF quote would have every test payment rejected. Overriding the quote keeps both
sides agreeing by construction — seats still counted, tiers still validated,
references still idempotent, under-payment still refused, and a **full period
still granted**. Only the number of francs changes.

Quotes keep reporting the real figures (`full_amount_rwf`, `test_mode`), so the
Licence tab shows the true price *and* a warning naming what will be taken. Two
safety properties, because a discount left on in production gives the product
away: it is **off unless enabled** by a service-role connection, and **it
expires** — an amount with no expiry is inert.

> Top-ups are priced client-side from `TopupPack` at 500 RWF and are unaffected.

### Two open gaps

> **Payments are client-reported.** The MoMo reference and amount reach `settle_*`
> from the client, which has already polled MTN. Enough to make crediting
> idempotent per reference and to catch under-reporting, but **not proof of
> payment** — a modified build could invent a reference. Closing it needs the
> data-connector to confirm each reference against
> `requesttopay/status/{reference}` and flip `payments.verified_by` to
> `'gateway'`. Until then rows stay `verified_by = 'client'` and reconcile
> against the MTN statement.

> **Phone-only accounts are student-only.** Firebase phone identities have no
> `profiles` row to carry a role, so a parent who signs in by SMS gets the
> student shell unless they have signed in with email on that device first.
> Fixing it means exchanging the Firebase credential for a Supabase session
> (custom JWT) — a backend job. Since a Rwandan parent is likelier to have a
> phone than an email, this is the highest-value remaining gap.

---

## Schools, classes, teachers and parents

### Enrolling

**Enrolment needs the join code**, not a school id. `enrol_by_code()` resolves the
code and inserts the membership server-side, so a client never names the school
itself. Before that, any signed-in user could browse the world-readable catalog,
enrol into a school they had nothing to do with, consume one of its paid seats
and raise its invoice.

Students see only their own schools (`mySchoolsProvider`); the empty state offers
the code rather than a list to pick from. The one direct insert still allowed is
a **second class inside a school you already belong to** — it adds no seat (seats
count distinct students) and is how a student picks up another subject.

| Account | May insert a membership |
|---|---|
| student | `student`, via `enrol_by_code` — plus another class in a school they are already in |
| school admin | `owner` / `teacher`, only in a school it created |
| teacher | nothing — added by redeeming a code |
| parent | nothing — a parent follows a child through `parent_students` |

### Linking a parent to a child

Both directions produce the same `parent_students` row and are redeemed by the
same function, so neither can drift from the other.

| Direction | Who mints the code | Who redeems it |
|---|---|---|
| `parent_of_student` | school admin (**People** tab) or the class teacher | the parent |
| `student_of_parent` | parent (**My children**) | the student |

Codes are seven characters from an alphabet with no `0/O`, `1/I/L`, `5/S` or
`8/B` — they get read down a phone or off a whiteboard. They last 30 days and
work once. `redeem_invite()` decides which side of the link the signed-in account
fills in, and refuses a code offered to the wrong role.

### Teachers

A director delegating to teachers is the difference between a 3-class pilot and a
30-class school. An admin mints a code on the **People** tab; the teacher signs up
normally, chooses *Enter a code* from the menu, and lands in their own shell:

- **Classes** — their school's classes, each with the join code that fills it,
  and a way to add one.
- **Progress** — students across their classes, grouped as *getting things wrong*,
  *not started yet* and *doing fine*. Absent and struggling are never merged into
  one pile: they call for different responses. A student who has answered no
  checks shows `—`, not `0%`.
- A class page with the roster, the join code, and **Invite parent** per student.

Three rules the implementation holds to:

- **The role is granted by invitation, never chosen.** `role_from_metadata` does
  not accept `'teacher'`, so a sign-up cannot claim it; only `redeem_invite`
  promotes an account. A self-declared teacher would be a stranger asking to read
  children's progress.
- **A teacher consumes no seat.** `school_seats_used()` counts students only, and
  `access_state()` covers a teacher through their employer's licence.
- **Aggregates, not conversations.** `class_progress()` returns counts and an
  accuracy per student. A teacher never gains the right to read raw
  `learning_events`, because a child's tutor questions are their own.

> **Not built yet: teacher ↔ parent messaging.** The parent Messages tab reads
> seeded content, so a real thread means replacing the seed on both sides with a
> messages table.

### Data model

```
profiles (id, role, display_name, phone)     -- student | parent | teacher | school_admin
schools (id, name, description, join_code, created_by)
   ├── classes (id, school_id, name, grade, join_code, created_by)
   └── school_licenses (school_id, tier_id, status, seats_purchased,
                        trial_ends_at, current_period_end)
memberships (id, user_id, school_id, class_id?, role)  -- student | teacher | owner
learning_events (id, user_id, kind, subject, is_correct, created_at)
parent_students (id, parent_id, student_id, source)    -- parent | school
parent_subscriptions (id, parent_id, plan_id, status, children_covered,
                      current_period_end)
invites (id, kind, code, school_id?, student_id?, parent_id?, status, expires_at)
payments (id, reference UNIQUE, payer_id, purpose, amount_expected_rwf,
          amount_reported_rwf, status, verified_by)
```

`class_id` is null for a school-level membership. A user sees their own
membership rows; an admin sees their school's roster; a teacher sees their
school's. `payments.reference` is MTN's id and is **unique** — that uniqueness is
what makes crediting idempotent, so replaying a settlement can never grant a
second period.

Every write that grants access (activating a licence, extending a subscription,
creating a family link, enrolling) goes through a `security definer` function.
There is deliberately **no insert/update policy** on `school_licenses`,
`parent_subscriptions` or `parent_students`, so a client cannot set
`status = 'active'` by itself.

---

## Mobile Money

Licence and top-up payments use the same gateway as Flipper
(`packages/flipper_services/lib/HttpApi.dart`), so the contract is identical:

1. `POST {MOMO_API_URL}/v2/api/payNow` with
   `{amount, currency: "RWF", payer: {partyIdType: "MSISDN", partyId}, …}`
   → HTTP 200/202 and a `paymentReference` (or `externalId`).
2. Poll `GET {MOMO_STATUS_API_URL}/v2/api/requesttopay/status/{reference}/{branchId}`
   every 12s for up to 5 minutes until MTN reports `SUCCESSFUL`.

Rules the implementation holds to:

- **`branchId` must match** between payNow and the status URL, or MTN 404s.
- A **non-2xx status read is "no verdict yet"**, not a failure — polling
  continues. A pending status that carries a *reason* surfaces it, so a gateway
  that cannot reach MTN is not mistaken for a slow payer.
- An **unrecognised status string is treated as pending**. Nobody is told their
  money vanished because of an unfamiliar verdict.
- On timeout the UI says *"still waiting for your approval… do not pay twice"* —
  it never claims the payment failed.
- Access is granted **only against a confirmed settlement reference**, and
  crediting is idempotent per reference.
- A refused request surfaces **the gateway's own message**; the payer's MSISDN is
  masked to its last three digits in logs.

Numbers are normalised the way Flipper does (`MomoMsisdn`): digits only, MTN
`78/79` and Airtel `72/73` prefixes, `250` + nine digits on the wire.

---

## How offline login works

1. On a successful **online** sign-in, the app caches a small record in the
   **OS-encrypted secure store** (`flutter_secure_storage`): the user profile,
   the provider, and the last refresh token. It never leaves the device.
2. The user sets an **offline PIN** (menu → *Set/change offline PIN*). Only a
   random salt and a **PBKDF2-HMAC-SHA256** hash are stored — never the PIN.
3. Launching **without a live session** but with a cached credential shows the
   **Offline unlock** screen. The correct PIN restores the cached session
   (`AuthSession.isOffline == true`).
4. When connectivity returns, Supabase silently refreshes the real session.

Secrets stay in the keychain by design — a syncing DB is the wrong place for
them. Ditto/Drift/Isar are the right tools for the **data** layer (lessons,
progress) and can be added behind the existing repository seam.

---

## Getting started

### 1. Prerequisites

- Flutter 3.44+ (`flutter --version`)
- A Supabase project (URL + publishable/anon key)
- Optional, for SMS: a Firebase project with Phone auth enabled

### 2. Configure secrets

```bash
cp env.example.json env.json   # git-ignored; fill in your values
```

### 3. Create the database schema

Run these in the Supabase SQL editor (**SQL Editor → New query**), in order. All
are safe to re-run.

| Migration | Adds |
|---|---|
| `0001_schools.sql` | schools, classes, memberships + RLS |
| `0002_progress.sql` | `learning_events` (append-only progress) |
| `0003_identity_and_billing.sql` | `profiles` (the server-side role), licences, subscriptions, family links, invites, payments, and `access_state()` |
| `0004_role_repair_and_enrolment_rules.sql` | repairs roles flattened by 0003's first backfill; restricts who may enrol |
| `0005_test_pricing.sql` | the bounded, self-expiring price override |
| `0006_teachers.sql` | the teacher role, teacher invites, `class_progress()` |
| `0007_enrol_by_code.sql` | `enrol_by_code()`; enrolling now requires the code |
| `seed.sql` | optional demo schools and classes |

> **All of them are required.** Without `0003` there is no `profiles` table and
> no `access_state()`, so every account reads back as an unpaid student: no admin
> shell, no create-school step, no payment gate. The app detects this and says so
> on screen, but it cannot fix itself.

> **If you signed up before applying `0003`,** run `0004`. The first version of
> `0003`'s backfill wrote `student` for every existing account, ignoring the role
> chosen at sign-up, and the protect-role trigger then stopped the app correcting
> it. To convert one account deliberately:
>
> ```sql
> select public.set_account_role(
>   (select id from auth.users where email = 'you@example.com'),
>   'school_admin');   -- or 'parent' / 'teacher' / 'student'
> ```

### 4. Run

```bash
flutter run -d windows --dart-define-from-file=env.json   # or android / chrome / macos
```

> The app **boots without `env.json`** — online auth is disabled, and you can
> still exercise the UI and the offline flows.

---

## Testing

Everything runs headless via `flutter test` — no device, no network, no Supabase.
The flow tests swap the data layer for in-memory fakes at the repository
boundary, so the **real** app (router, theme, screens, controllers) is what gets
exercised.

| Layer | Files | What it guards |
|---|---|---|
| Unit | `test/unit/` | Entitlement parsing and its fail-closed defaults, design tokens per platform, the ink model + undo/redo, MoMo number handling and the whole payNow/polling contract, repositories, mastery derivation, formatters, entity JSON |
| Widget | `test/widget/` | The shared UI kit, all four platform shells, and every student / parent / teacher / admin screen — rendered with the **real theme** at mobile and desktop sizes |
| Flows | `test/flows/`, `test/*_flow_test.dart` | Sign-in and failure, offline PIN set/unlock, sign-up role picking, enrol by code, licence and family-plan payments (settle / reject / time out / test pricing), family linking both directions, teacher invite and class management, and the role guards that keep each action to the accounts allowed to perform it |

`test/support/` holds the fakes (`FakeAuthRepository`, `FakeAccessRepository`,
`FakeLinkingRepository`, `FakeTeacherRepository`, `FakePaymentsRepository`,
`RecordingHttpClient`, …) and `pumpApp()`, which boots the real `EduAiApp` with
those fakes injected through `ProviderScope` overrides. Add a journey by writing
another `*_flow_test.dart`.

Two things to know when writing tests here:

- Rasterising ink (`rasterizeStrokes`, used by the workbook's AI check) needs the
  real raster thread — drive it inside `tester.runAsync(...)`.
- `AppBadge` renders uppercase as a visual treatment but announces its label as
  written, so find it with `find.text('REB ALIGNED')` or
  `find.bySemanticsLabel('REB aligned')`.

### The SQL is tested too

The migrations carry the rules that money depends on, and Dart tests cannot reach
them. They are exercised by applying `0001`–`0007` to a scratch PostgreSQL 15 and
asserting the commercial path end to end: the trial trigger, server-side pricing,
under-payment refusal, settlement idempotency, invite single-use, the seat
accounting, and the RLS policies as the `authenticated` role rather than as
superuser (which bypasses RLS entirely).

That harness is not yet in CI — it needs a Postgres service container and a
Supabase-shaped `auth` stub. Until it is, re-run it by hand when touching
`supabase/migrations/`.

> These tests give high confidence in the critical paths, but no suite proves an
> app is bug-free. Add a test for every bug found and every new flow.

---

## Firebase phone (SMS) setup

Firebase phone auth runs on **Android, iOS and Web** — not desktop. To enable it:

1. `dart pub global activate flutterfire_cli`
2. `flutterfire configure` (generates platform config + `firebase_options.dart`)
3. Firebase console → **Authentication → Phone**.
4. On Android, add your SHA-1/SHA-256 signing keys.

`FirebasePhoneAuthDataSource` activates automatically once Firebase initialises on
a supported platform. On desktop the SMS button explains it is unavailable and
falls back to email / offline PIN.

---

## What's intentionally deferred

- **Per-child progress for parents.** Parent reports (minutes, mastery, activity,
  teacher thread) still come from the seed source. The **links** are real: with a
  backend, `parentChildrenProvider` lists the children actually in
  `parent_students`. Missing is the per-child rollup over `learning_events` plus
  the RLS to let a parent read their own child's rows — the teacher side of that
  rollup already exists as `class_progress()`.
- **Server-verified payments** and **roles for phone-only accounts** — the two
  open gaps described [above](#two-open-gaps).
- **Teacher ↔ parent messaging** — needs a messages table replacing the seed on
  both sides.
- **The Usage tab's numbers.** `UsageStats` is the last seeded surface in the
  admin shell. Display-only — no money decision reads it.
- **The handwriting-check endpoint.** `POST /api/edu/workbook/check` is not
  deployed; the client is written to its agreed contract and reports "not
  available yet".
- **Localization.** The language picker persists a choice, but the ARB bundles are
  not authored; switching `MaterialApp.locale` first would strip Material's own
  localisations (`flutter_localizations` ships no `rw`) without translating any
  EduAI copy.
- **Frameless desktop windows.** macOS/Windows chrome is approximated in-app
  rather than pulling in `window_manager` / `bitsdojo_window`.
- **Persisted lesson annotations.** Highlighter marks live as long as the reader
  is open.
- **Analytics / crash reporting** — `AppLogger` is the seam.
