# EduAI

An offline-first Flutter app for *education with AI*, built for Rwandan
students, their parents and their schools. One codebase renders native-feeling
chrome on **iOS, Android, macOS and Windows**.

- **Four roles, four shells** — Student (Home / Tutor / Workbook / Lessons /
  Progress), Parent (Overview / Reports / Messages / Plan), Teacher (Classes /
  Progress) and School admin (License / People / Invoices / Usage), pinned
  server-side. Three are chosen at sign-up; **teacher is granted only by
  redeeming a code the school minted**
- **Two ways to pay** — a school buys per-seat licences after a 30-day trial, or
  a parent with no school subscribes per child. A student is entitled by either;
  see [Who pays, and for what](#who-pays-and-for-what)
- **Stylus-first** — a pressure-sensitive ink canvas powers the Workbook, the
  Tutor scratchpad and lesson annotation
- **Offline-first** — bundled REB-aligned lessons, cached catalogs, and a
  device PIN that unlocks the app with no internet
- **Mobile Money** — school licences, family plans and optional parent top-ups
  pay through the same MTN gateway Flipper uses
- **Supabase** email/password auth, **Firebase phone (SMS)** verification
- **Riverpod** state management in a clean **feature-first** architecture

---

## Architecture

Feature-first clean architecture. Each feature owns three layers; `core/` holds
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
│   ├── error/                    # Failure hierarchy + Result<T>
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
    ├── tutor/                     # AI chat with blocks + pen scratchpad
    ├── workbook/                 # 3-page stylus notebook + AI handwriting check
    ├── lessons/                  # REB catalog, offline download, reader
    ├── progress/                 # mastery rings, streak, exam readiness
    ├── parent/                   # children, reports, teacher thread, plan
    ├── billing/                  # price list, roster, payment ledger, usage
    └── payments/                 # Mobile Money (payNow + request-to-pay polling)
```

Every feature keeps the same four layers: `domain/` (entities + repository
interface), `data/` (sources + implementation), `application/` (Riverpod
controllers) and `presentation/` (screens + widgets).

### The dependency rule

`presentation → application → domain ← data`

Presentation talks to Riverpod controllers; controllers call the
`AuthRepository` interface; the repository implementation orchestrates the data
sources. Swap any layer (e.g. a fake repository in tests) via a provider
override.

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

A student, a parent and a school admin are **different signed-in identities**,
not a runtime toggle: `AppUser.role` drives which `StatefulShellRoute` the
router redirects to, and a deep link into another role's shell bounces home. A
debug-only "View as" item in the More menu makes the other shells reachable
without minting three accounts.

The role is chosen **once, at sign-up**, and stored server-side on
`public.profiles`. It is deliberately not read from Supabase user metadata: a
client can write its own metadata, and it stays writable afterwards. A trigger
validates the requested role against an allowlist on account creation, and a
second trigger refuses any later change that carries an end-user JWT — so
converting an account is a support action, not a client action.

`ProfileRemoteDataSource.fetchRole` returning null means *"do not change what
you already believe"*, never "student". A dropped request must not demote a
school director to the student shell; the session falls back to the role this
device last cached.

---

## Who pays, and for what

This is the core commercial flow, so it is spelled out end to end. There are
**two revenue lines** and a student is entitled by **either** of them.

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

- Creating a school is what **starts the trial clock**. A school can never
  exist in an unknown billing state — the licence row is created by trigger.
- Only a `school_admin` identity can insert a school. This is enforced in RLS
  (`schools_insert_self` checks `my_role()`), not just by hiding the button.
- Seats are **counted from the roster**, not typed in. An admin controls how
  many seats they *buy*; `school_seats_used()` counts enrolled students. The
  bill is the larger of the two, so a school cannot enrol 300 students against
  50 purchased seats and pay for 50.
- Paying during a trial **adds a period** rather than forfeiting the days left.

### B. A parent subscribes directly (B2C)

```
sign up as "I am a parent"         → profiles.role = 'parent'
        ↓
link a child (either direction, below)
        ↓
no school licence covers that child?
        ↓
Plan tab: family plan, priced per linked child → settle_parent_subscription()
```

A parent **never creates a school**. If their child's school already has a
licence, `access_state()` reports `source: school_license` and the Plan tab
leads with *"Included in {school}'s EduAI plan"* — the school-paid check runs
**before** the parent's own subscription, so a parent is never asked to pay for
access somebody already bought.

### How a school adds a parent

Both linking directions produce the same thing — a row in `parent_students` —
and are redeemed by the same function, so neither can drift from the other.

| Direction | Who mints the code | Who redeems it |
|---|---|---|
| `parent_of_student` | school admin, from the **People** tab | the parent |
| `student_of_parent` | parent, from **My children** | the student |

Codes are seven characters from an alphabet with no `0/O` or `1/I` (they get
read down a phone), last 30 days, and work once. `redeem_invite()` decides which
side of the link the signed-in account fills in, and refuses a code offered to
the wrong role.

### Teachers

A director delegating to teachers is the difference between a 3-class pilot and
a 30-class school. An admin mints a code on the **People** tab; the teacher signs
up normally, opens the menu, chooses *Enter a code*, and lands in their own
shell:

- **Classes** — their school's classes, each with the join code that fills it,
  and a way to add one.
- **Progress** — every student across their classes, grouped as *getting things
  wrong*, *not started yet* and *doing fine*. Absent and struggling are never
  merged into one "needs attention" pile, because they call for different
  responses. A student who has answered no checks shows `—`, not `0%`.
- A class page with the roster, the join code, and **Invite parent** per student.

Three rules the implementation holds to:

- **The role is granted by invitation, never chosen.** `role_from_metadata` does
  not accept `'teacher'`, so a sign-up cannot claim it; only `redeem_invite` can
  promote an account, and it does so through a session-local flag that the
  role-protection trigger recognises. A self-declared teacher would be a
  stranger asking to read children's progress.
- **A teacher consumes no seat.** They are billed as staff, not students:
  `school_seats_used()` counts `role = 'student'` only, and `access_state()`
  covers a teacher through the licence of the school that employs them.
- **Aggregates, not conversations.** `class_progress()` is a security-definer
  function returning counts and an accuracy per student. A teacher never gains
  the right to read raw `learning_events`, because a child's tutor questions are
  their own.

> **Not built yet: teacher ↔ parent messaging.** The parent Messages tab still
> reads seeded content, so making a real thread means replacing the seed on both
> sides with a messages table. It is the one thing in the teacher brief this pass
> does not deliver.

### Who may enrol in a school

A seat belongs to a **student**. Enrolment is refused for anyone else, in the
client (`SchoolsActionController`, one guard every join path funnels through)
and in RLS (`may_enrol()`), because a director joining another school would
consume a seat on that school's licence and put their admin identity inside
somebody else's roster.

**Enrolment needs the join code**, not a school id. `0007` moved it into
`enrol_by_code()`, a security-definer function that resolves the code and
inserts the membership itself. Before that, `may_enrol` accepted any school id:
the catalog is world-readable to signed-in users, so anybody could browse to a
school they had nothing to do with, enrol, consume one of its paid seats and
raise its next invoice. That fell out of the schools list being a
browse-and-join catalog from before there was anything to bill.

The one direct insert still allowed is a **second class inside a school you
already belong to** — it adds no seat (seats count distinct students) and it is
how a student picks up another subject.

Students see only their own schools (`mySchoolsProvider`), and the empty state
offers the code rather than a list to pick from.

| Account | May insert |
|---|---|
| student | `student` membership, but **only via `enrol_by_code`** — and directly in a school they already belong to, to pick up another class |
| school admin | `owner` / `teacher`, and only in a school it created |
| parent | nothing — a parent follows a child through `parent_students` |
| teacher | nothing — added by redeeming a code, never by self-enrolment |

### The entitlement gate

One server function, `access_state()`, answers *"may this account use EduAI,
and until when?"* in a single round trip. Everything in the UI reads its result
through `accessSnapshotProvider`; no screen assembles entitlement itself, so no
two screens can disagree.

| status | meaning |
|---|---|
| `entitled` | paid and current |
| `trialing` | inside the trial window — full access, on a clock |
| `needs_payment` | there is something to bill and it has not been paid |
| `needs_setup` | nothing to bill yet (no school / no child linked) |

**What locks, and what never does.** Only the surfaces that cost money to run
stop: the AI Tutor (`AccessGate`) and the workbook's AI check. Lessons, the
workbook canvas, saved pages and a student's own progress stay open when a
licence lapses. Holding a child's completed work hostage over their school's
invoice is not a collections strategy.

**Failure modes are deliberate.** An unrecognised status parses as `unknown`,
not `entitled`, so a server that grows a new state cannot accidentally hand out
access. A cached entitlement has its status recomputed against the clock, so a
month offline past renewal is not a free month. And `unknown` counts as
*allowed* for the brief moment before the first response arrives — the server
rejects unentitled work anyway, and flashing a paywall at every cold start
would punish paying users for their latency.

**Builds with no Supabase** (design review, widget tests) cannot enforce
anything, so `AccessState.unconfigured()` opens the app up with
`enforced: false`. That flag is what stops the UI claiming a plan was paid for:
the parent Plan tab shows the demo plan rather than inventing either a charge
or a payer.

### Testing a payment without paying a real licence

Testing this flow needs real money to move — MTN has to prompt a real handset
and settle a real reference — and a school licence starts at 7,500 RWF. So
non-production projects can charge a token amount instead:

```sql
-- in the Supabase SQL editor (service role; a signed-in client is refused)
select public.enable_test_pricing(100, 24);   -- 100 RWF, for the next 24 hours
select public.disable_test_pricing();         -- back to real pricing
```

The override lives in the **quote**, not the client, and that is the whole
design. `settle_school_license()` and `settle_parent_subscription()` recompute
the amount from the same quote function and record anything short of it as
`disputed` — so a client that simply paid 100 RWF against a 7,500 RWF quote
would have every test payment rejected. Overriding the quote keeps both sides
agreeing by construction: seats are still counted, tiers still validated,
references still idempotent, under-payment still refused, and a **full period is
still granted**. Only the number of francs changes.

Quotes keep reporting the real figures (`seats`, `price_per_seat_rwf`,
`full_amount_rwf`, `test_mode`), so the Licence tab shows the true price *and* a
warning naming what will actually be taken. The parent plan grid prices from the
static list, so it gets the same warning above the cards.

Two safety properties, because a discount left on in production gives the
product away:

- **Off unless enabled**, and only by a service-role/SQL-editor connection.
  `enable_test_pricing` raises if `auth.uid()` is non-null.
- **It expires.** An amount with no expiry is inert, and a forgotten override
  stops applying on its own instead of quietly discounting a real school. Both
  `test_charge_amount_rwf` and `test_charge_until` must be live for it to count.

> Top-ups are priced client-side from `TopupPack` and are already 500 RWF, so
> they are not affected by this switch.

### Prices live on the server

`plan_tiers` and `parent_plans` are tables, and every `settle_*` function
**recomputes the amount** before granting anything. The client asks for a quote,
shows exactly it, and pays exactly it. A modified build cannot buy the District
tier for 1 RWF; an under-reported settlement is recorded as `disputed` and
activates nothing, so the money is traceable rather than lost.

> **Open trust gap.** The MoMo reference and amount reach `settle_*` from the
> client, which has already polled MTN. That is enough to make crediting
> idempotent per reference and to catch under-reporting, but it is **not proof
> of payment** — a modified build could invent a reference. Closing it needs a
> server-side confirmation: the data-connector calling
> `requesttopay/status/{reference}` itself and flipping `payments.verified_by`
> to `'gateway'`. Until that job exists, rows stay `verified_by = 'client'` and
> are reconcilable against the MTN statement.

> **Phone-only accounts are student-only.** Phone identities live in Firebase,
> not Supabase, so they have no `profiles` row to carry a role. A parent who
> signs in by SMS gets the student shell unless they have signed in with email
> on that device first. Fixing this properly means exchanging the Firebase
> credential for a Supabase session (custom JWT) — a backend job, not a client
> one. Since a Rwandan parent is far more likely to have a phone number than an
> email address, this is the highest-value remaining gap in the flow.

---

## Mobile Money

Licence and top-up payments go through the same gateway as Flipper
(`packages/flipper_services/lib/HttpApi.dart`), so the contract is identical:

1. `POST {MOMO_API_URL}/v2/api/payNow` with
   `{amount, currency: "RWF", payer: {partyIdType: "MSISDN", partyId}, …}`
   → HTTP 200/202 and a `paymentReference` (or `externalId`).
2. Poll `GET {MOMO_STATUS_API_URL}/v2/api/requesttopay/status/{reference}/{branchId}`
   every 12s for up to 5 minutes until MTN reports `SUCCESSFUL`.

Rules the implementation holds to:

- **`branchId` must match** between payNow and the status URL, or MTN 404s.
- A **non-2xx status read is "no verdict yet"**, not a failure — polling
  continues.
- An **unrecognised status string is treated as pending**. A parent is never
  told their money vanished because of an unfamiliar verdict.
- On timeout the UI says *"still waiting for your approval… do not pay twice"* —
  it never claims the payment failed.
- Sessions are credited **only against a confirmed settlement reference**, and
  crediting is idempotent per reference.

Numbers are normalised the same way Flipper does (`MomoMsisdn`): digits only,
MTN `78/79` and Airtel `72/73` prefixes, `250` + nine digits on the wire.

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
# in the Supabase SQL editor, paste & run, in this order:
#   supabase/migrations/0001_schools.sql              (schools/classes/memberships + RLS)
#   supabase/migrations/0002_progress.sql             (learning events)
#   supabase/migrations/0003_identity_and_billing.sql (roles, licences, invites, payments)
#   supabase/migrations/0004_role_repair_and_enrolment_rules.sql
#   supabase/migrations/0005_test_pricing.sql
#   supabase/migrations/0006_teachers.sql
#   supabase/migrations/0007_enrol_by_code.sql
#   supabase/seed.sql                                  (optional demo schools/classes)
```

> **All four are required.** Without `0003`, `profiles` and `access_state()` do
> not exist, so every account silently reads back as an unpaid student: no admin
> shell, no create-school step, no payment gate. The app now detects this and
> says so on screen instead of looking like it is working — but it cannot fix
> itself.
>
> **If you signed up before applying `0003`**, run `0004`: the first version of
> `0003`'s backfill wrote `student` for every existing account, ignoring the role
> chosen at sign-up, and the protect-role trigger then stopped the app correcting
> it. `0004` re-derives roles from sign-up metadata and is safe to re-run. To
> convert one account deliberately, from the SQL editor:
>
> ```sql
> select public.set_account_role(
>   (select id from auth.users where email = 'you@example.com'),
>   'school_admin');  -- or 'parent' / 'student'
> ```

`0001` creates `schools`, `classes` and `memberships` with Row Level Security so
the publishable/anon key is safe in the client: anyone signed in can read the
catalog, but a user can only see and change **their own** memberships.

`0003` is what makes the app sellable — see [Who pays, and for
what](#who-pays-and-for-what). It adds `profiles` (the server-side role),
`school_licenses`, `parent_subscriptions`, `parent_students`, `invites` and
`payments`, plus the `access_state()` function the client trusts for every
access decision. It is safe to re-run, and it **backfills an existing
database**: every account gets a profile, every pre-existing school gets a trial
licence rather than silently becoming free forever, and whoever created a school
becomes its admin.

It also **tightens `0001`**, which let any authenticated user insert a school —
the reason anybody could stand up a school for free. After `0003`, creating a
school requires `my_role() = 'school_admin'`, and classes belong to their
school's own admin.

Every write that grants access (activating a licence, extending a subscription,
creating a family link) goes through a `security definer` function. There is
deliberately **no insert/update policy** on `school_licenses`,
`parent_subscriptions` or `parent_students`, so a client cannot set
`status = 'active'` by itself.

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
| Unit | `test/unit/` | Design tokens per platform, the ink model + undo/redo, MoMo number handling and the whole payNow/polling contract, lesson/parent/billing repositories, mastery derivation, formatters, role routing, entity JSON |
| Widget | `test/widget/` | The shared UI kit, each of the four platform shells, and every student / parent / admin screen — rendered with the **real theme** at mobile and desktop sizes |
| End-to-end flows | `test/*_flow_test.dart`, `test/flows/` | Sign-in (success + failure), offline PIN set / unlock, browse → join a class → see it on home, join-by-code, create school / class, lesson download → read → complete, tutor pen attach, MoMo top-up settle / reject / time out |

Run everything:
```bash
flutter test --coverage
```

Line coverage is **above 80%**. What is deliberately not covered is the
Supabase- and Firebase-bound data sources, which need a live backend rather than
a unit test.

`test/support/` holds the fakes (`FakeAuthRepository`, `FakeSchoolsRepository`,
`FakePaymentsRepository`, `RecordingHttpClient`, …) and `pumpApp()`, which boots
the real `EduAiApp` with those fakes injected via `ProviderScope` overrides —
so the router, theme, shells, screens and controllers under test are the
shipped ones. Add a new journey by writing another `*_flow_test.dart`.

Two things to know when writing tests here:

- Rasterising ink (`rasterizeStrokes`, used by the workbook's AI check) needs
  the real raster thread — drive it inside `tester.runAsync(...)`.
- `AppBadge` renders uppercase as a visual treatment but announces its label as
  written, so find it with `find.text('REB ALIGNED')` or
  `find.bySemanticsLabel('REB aligned')`.

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
- **Create** a school or class — **school-admin identities only**. The creator is
  enrolled as `owner`/`teacher`, and the new school starts a 30-day trial
  licence by trigger.
- **Offline** — the last-fetched catalog and your memberships are cached
  (`shared_preferences`), so an offline-unlocked user still sees them. Writes
  (join/create) require a connection and surface a clear message otherwise.

Data model:

```
profiles (id, role, display_name, phone)          -- role: student|parent|school_admin
schools (id, name, description, join_code, created_by)
   ├── classes (id, school_id, name, grade, join_code, created_by)
   └── school_licenses (school_id, tier_id, status, seats_purchased, trial_ends_at,
                        current_period_end)
memberships (id, user_id, school_id, class_id?, role)   -- role: student|teacher|owner
parent_students (id, parent_id, student_id, source)     -- source: parent|school
parent_subscriptions (id, parent_id, plan_id, status, children_covered,
                      current_period_end)
invites (id, kind, code, school_id?, student_id?, parent_id?, status, expires_at)
payments (id, reference UNIQUE, payer_id, purpose, amount_expected_rwf,
          amount_reported_rwf, status, verified_by)
```

> `class_id` is null for a school-level membership. A user sees their own
> membership rows; a school admin additionally sees their own school's roster.
> `payments.reference` is MTN's id and is unique — that uniqueness is what makes
> crediting idempotent, so replaying a settlement can never grant a second
> period.

## What's intentionally deferred

- **Per-child progress for parents.** Parent-facing *reports* (minutes, mastery,
  activity, teacher thread) still come from the seed source. The **links** are
  real: with a backend, `parentChildrenProvider` lists the children actually in
  `parent_students`, and a parent with none linked gets the empty state and a way
  to fix it rather than two invented children. What is missing is the per-child
  rollup over `learning_events`, plus the RLS to let a parent read their own
  child's rows.
- **Server-verified payments.** See the trust gap under [Who pays, and for
  what](#who-pays-and-for-what) — the data-connector needs to confirm each MoMo
  reference against MTN and flip `payments.verified_by` to `'gateway'`.
- **Roles for phone-only accounts.** Also noted above: Firebase phone identities
  have no `profiles` row, so they land in the student shell.
- **The Usage tab's numbers.** `UsageStats` is the one screen in the admin shell
  still showing seeded figures. It is display-only — no money decision reads it —
  and it needs the same `learning_events` rollup as parent reports.
- **The handwriting-check endpoint.** `POST /api/edu/workbook/check` is not
  deployed yet. The client is written to its agreed contract and reports
  "not available yet" until it ships.
- **Localization.** The language picker persists a choice, but the ARB bundles
  are not authored; switching `MaterialApp.locale` before then would only strip
  Material's own localisations (`flutter_localizations` ships no `rw`) without
  translating any EduAI copy.
- **Frameless desktop windows.** macOS/Windows chrome is approximated in-app
  rather than pulling in `window_manager` / `bitsdojo_window`; the OS still
  draws the real title bar and its caption buttons.
- **Persisted lesson annotations.** Highlighter marks live as long as the
  reader is open; whether they should survive a session is a data-model
  decision that has not been taken.
- **Analytics / crash reporting** — `AppLogger` is the seam.
