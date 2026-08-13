# Handoff: EduAI Redesign (Flutter)

## Overview
Premium, cross-platform redesign of the EduAI Flutter app (`yegobox/eduAi`) — a native-feeling learning app for Rwandan students and parents, with stylus/pen support for handwritten math working, and a monetization layer (school B2B licenses + optional parent top-ups) aimed at ~1,000,000 RWF/month recurring revenue.

It covers three personas: **Student** (Home, AI Tutor, Workbook, Lessons, Progress), **Parent** (Overview, Reports, Messages, Plan/Billing), and **School Admin** (License, Seats, Invoices, Usage) — and one adaptive shell that looks native on iOS, Android, macOS and Windows.

## About the design files
The bundled HTML/CSS/JSX files are **design references built as an interactive web prototype** — they show intended layout, states, and behavior, not code to port directly. The task is to **recreate this design in the existing Flutter codebase**, using its established architecture (Riverpod, go_router, feature-first `domain/data/application/presentation` layers) — not a WebView embed.

Open `EduAI Redesign.html` in a browser to click through all screens, platforms and roles live (top bar has Platform / View as / Appearance switches).

## Fidelity
**High-fidelity.** Colors, radii, spacing, type scale and copy in the prototype are final intent — implement pixel-close using Flutter's own widgets (Material for Android, Cupertino-flavored widgets for iOS, desktop chrome for macOS/Windows), not a literal HTML/CSS-to-Flutter transcription.

## Platform adaptation strategy
One shared screen/widget tree per feature; only **navigation chrome** and a few tokens (radius, type scale, control shapes) change per platform. Suggested Flutter approach:

- Detect platform via `Theme.of(context).platform` / `defaultTargetPlatform` (already how Flutter separates mobile vs desktop builds); expose an `AppPlatformStyle` enum (`ios`, `android`, `macos`, `windows`) via a Riverpod provider, defaulting from the real OS but not user-switchable in production (the prototype's top switcher is a **demo-only** tool, not a feature to ship).
- **iOS**: `CupertinoPageScaffold`-style nav bar (large title collapsing to inline on push) + bottom tab bar (`CupertinoTabBar` or Material `NavigationBar` styled with 20px card radius, SF-style type). Back = leading chevron.
- **Android**: Material 3 `NavigationBar` (already Material 3 themed in `app_theme.dart`), `AppBar` top bar, 16px card radius, ripple states.
- **macOS**: no bottom/side nav — a **centered segmented control in the window toolbar** (next to traffic-light-adjacent title) switches sections; back = leading chevron pill in the toolbar. Use `PlatformMenuBar` for the app menu and a package like `window_manager` for custom title-bar behavior if you build a real frameless window; otherwise a plain `AppBar`-as-toolbar with `titleSpacing:0` approximates it.
- **Windows**: title bar (app icon + name + min/max/close — `bitsdojo_window` or `window_manager` for a real custom frame) + an **underline tab strip** (Fluent "Pivot" pattern) below it for section switching, back = leading chevron next to the section title when a detail view is pushed.
- Reference the "Continue learning" cards on Home, which jump tabs directly — implement as `router.go()` to the tab's route rather than a nested Navigator push.

## Screens / Views

### Student — Home
- **Purpose**: landing surface; offline-PIN nudge, school/class membership, quick links into the 4 other tabs.
- **Layout**: single scrolling column, max content width ~900 on desktop. Greeting (`Hello, {name} 👋`, bold, platform H1 size) + streak subtitle. Offline-PIN banner: brand-soft card, lock icon tile, title + body + "Set PIN" button (dismissible). "My schools & classes" section header + "Browse" button, then a tappable school card (icon tile, name, "Class member • student", chevron) that pushes the Classroom detail view. "Continue learning" 2×2 (mobile: 1 col) grid of cards — AI Tutor, Workbook, Lessons, Progress — icon tile + title + one-line description, tapping jumps that tab.
- **Classroom detail** (pushed): school description, "Join this school" row with Join button, "Classes" list (name + grade + Join/Leave toggle button), "Add class" soft button at the bottom.

### Student — AI Tutor
- **Purpose**: conversational tutor matching the existing `tutor_screen.dart` contract (blocks: `text`, `example`, `check`, `followups`).
- **Empty state**: centered icon tile (sparkles), "Ask me anything you're studying" title, subtitle, 4 sample-prompt chips (wrap layout) — tapping sends that prompt.
- **Conversation**: user turns are right-aligned brand-filled bubbles; assistant turns render each block in order — `text` as plain paragraphs (`**bold**` → bold run), `example` as a soft card with a lightbulb-icon label, `check` as a single-question multiple-choice card that reveals correct/incorrect styling and an explanation on selection (no score kept — retrieval practice, not a test), `followups` as tappable chips that resend that text as the next question.
- **New in this redesign — pen attach**: a pen icon button in the composer toggles a small embedded scratchpad (grid-guide ink canvas, ~140px tall) above the composer with Clear / "Attach & ask" actions; attaching sends a fixed prompt ("Can you check my handwritten working?") to the tutor. This is the bridge between free-hand math and the chat.
- **Composer**: pen button, rounded text field ("Ask a question…"), circular send button (disabled while empty or while the assistant is "Thinking it through…", shown as a 3-dot pulse row).

### Student — Workbook (new)
- **Purpose**: a full stylus notebook for solving problems by hand, independent of any one question.
- **Layout**: header with "Workbook" title + 3 numbered page tabs (top-right). Toolbar row: 3 tool buttons (Pen / Highlighter / Eraser — icon buttons, active = brand-filled), a divider, 5 color swatches (only enabled when tool = pen), a divider, a 3-way guide switch (Grid / Lines / Plain), then Undo / Redo / Clear icon buttons pinned right. Below: the ink canvas, filling remaining height. Below that: a full-width primary button "Ask AI to check my work" which — once tapped — is replaced by a green feedback card (check icon + short verdict + one actionable tip, e.g. "check the sign when you divide both sides by 2").
- **Ink behavior**: pointer/stylus input, pressure-sensitive stroke width (thin pen ~3px base, highlighter ~16px at 35% opacity with normal blend, eraser ~20px using destination-out compositing). Undo/redo operate on a per-stroke history stack; each of the 3 pages keeps its own independent canvas state.
- **Flutter implementation note**: use `Listener`/`RawGestureDetector` + `CustomPainter`, reading `PointerEvent.pressure` (Flutter already reports this for `PointerDeviceKind.stylus` on iOS/Android/Windows Ink/Apple Pencil) to vary `Paint.strokeWidth`. Store strokes as `List<Offset>` + metadata per stroke in a small in-memory model per page (persist to local storage per lesson/page if you want work to survive app restarts).

### Student — Lessons
- **Purpose**: REB-aligned curriculum library, offline-first.
- **Catalog**: horizontal scroll of grade-band filter chips (Pre-primary, P1–P6, O-Level, A-Level, Exam prep) — one active at a time. Below: a responsive card grid (min ~150px per card) — cover tile (brand-soft gradient + book icon; swap for real thumbnail art per lesson later), subject label (uppercase, small), title (2-line clamp), a "REB aligned" badge when applicable, and a per-card download toggle icon (outline "download" → filled "check" once downloaded, tap to toggle without opening the lesson).
- **Lesson reader** (pushed): subject + REB badges at top, then the lesson body as normal reading-width paragraphs in a card. A floating "Annotate with pen" pill toggles a transparent highlighter-only ink overlay directly on the reading pane (default color: soft yellow) so students can mark up the text; toggling off just hides future drawing (marks persist visually while the overlay is mounted — decide with your data plan whether annotations should persist across sessions). "Mark as complete" primary button at the bottom feeds the Progress screen.

### Student — Progress
- **Purpose**: mastery over time, framed positively (not a scoreboard).
- **Mastery rings**: one ring per subject (Mathematics / English / Science in the mock) — a circular percentage ring (conic gradient equivalent: `CustomPainter` arc or `SweepGradient` on a `Container` with a decoration, or `flutter`'s `CircularProgressIndicator` styled with rounded caps) + subject label underneath, laid out in a wrapping row.
- **7-day streak**: a row of 7 small circles (M–S), filled brand-success when that day had activity.
- **REB exam readiness**: a labeled percentage + horizontal progress bar + one line of context copy.
- **Share toggle**: a row with a title/subtitle ("Share weekly report with parent" / "Your parent will see mastery, not every mistake") and a trailing switch — this is the flag `ParentReports` reads.

### Parent — Overview / Reports / Messages / Plan
- **Child switcher**: a horizontal row of pill tabs (avatar-initials + name) at the top of Overview and Reports — parents with more than one enrolled child switch between them here; persist the selection across those two tabs.
- **Overview**: 3 stat tiles (minutes this week / questions asked / streak days), an "attention" card listing 1+ subject/topic chips that need encouragement, a "Recent activity" list (icon + one-line event + relative time, ~4 rows), and a trust banner ("Works without internet" — reassurance that outages don't lose progress).
- **Reports**: per-subject mastery bars with percentages + one line reinforcing that reports show trends, not every wrong answer.
- **Messages**: a simple two-way thread with the class teacher (their messages left-aligned neutral bubbles, parent's own right-aligned brand bubbles, sender name + relative time under each), plain text composer + send button.
- **Plan (billing)**: a trust banner stating the child's access is **included in the school's EduAI plan at no extra cost**, renewal date, plan/seats summary row, then an **optional, clearly-labeled** top-up section (3 pricing cards: small/family/term packs in RWF, "Pay with MoMo" button per card) framed as "never required to keep learning," and a one-line privacy assurance ("data stays private — never sold or used for advertising"). This view must never read as a paywall.

### School Admin — License / Seats / Invoices / Usage
- **License**: 3-stat header row (plan tier / monthly cost / renewal date), a seats-used progress bar, and a 3-tier pricing comparison (Starter / Growth / District — price per student/month, seat range, feature bullets, current tier marked with a badge and "Current plan" disabled state, others get "Switch plan").
- **Seats**: one row per class with a name and a stepper (±5 seats) control, total seat count badge at top, "Add a class" action at the bottom.
- **Invoices**: a simple table (Invoice ID / Date / Amount RWF / Status badge / download icon) plus a note that receipts are emailed automatically after Mobile Money payment.
- **Usage**: 3 stat tiles (active-student %, sessions/student/week, mastery lift %) + a highlighted "most-practised subject" row + a line framing this as renewal-conversation ammunition for the school board.

## Interactions & behavior
- **Tutor send**: optimistic user bubble append → ~900ms simulated "thinking" state (replace with the real `/api/edu/tutor/chat` call already wired in `tutor_repository_impl.dart`) → assistant blocks appended, auto-scroll to bottom.
- **Workbook "Ask AI to check my work"**: currently a static mocked verdict in the prototype — real implementation should rasterize/vectorize the current page's strokes and send to a vision-capable check endpoint (new; not yet in the repo), returning short structured feedback (verdict + one tip), matching the tone of the tutor's `check` block.
- **Lesson download toggle**: optimistic local toggle; wire to the offline cache (same `shared_preferences`/repository pattern the schools feature already uses for cached catalogs).
- **Progress share switch**: writes a `shared: bool` flag the Parent Reports screen's data source reads — no separate parent-facing toggle.
- **Classroom Join/Leave**: matches existing `SchoolsActionController` behavior (online-only; show a clear offline message otherwise, as `school_detail_screen.dart` already does).
- **Top-up "Pay with MoMo"**: opens the real Mobile Money (MTN/Airtel) payment flow — the prototype just flips the card to an "Added ✓" state.
- **"More" menu** (kebab icon, present on every screen): Set/change offline PIN → existing `set_pin_screen.dart` flow; Language (English/Kinyarwanda/Français) → cycles/opens a picker, should drive real localization; Sign out → existing `AuthController.signOut()`.
- **Status chip** (Online/Offline, every screen header): bind to the existing `networkStatusProvider` / offline-session flag, exactly as today's `home_screen.dart` `_StatusChip`.

## State management
Follow the existing feature-first pattern (`domain` entities + repository interface → `data` sources/impl → `application` Riverpod controllers → `presentation` screens). New features needed, each its own folder under `lib/features/`:
- **lessons**: `Lesson`, `Subject`, `GradeBand` entities; `LessonsRepository` (catalog + per-lesson downloaded/offline-cache state, completion flag); controller exposing grade filter + download toggle + mark-complete.
- **workbook**: local-only for v1 (no repository needed) — a `WorkbookController` holding per-page stroke lists, tool/color/guide state, undo/redo stacks; a separate `WorkbookCheckRepository` once the AI-check endpoint exists.
- **progress**: `SubjectMastery`, `StreakDay` entities; `ProgressRepository` aggregating tutor/lesson/workbook activity into mastery %, streak, exam-readiness, and the parent-share flag.
- **parent**: `Child`, `Message`, `ParentPlan`, `TopupPack` entities; `ParentRepository` (children list scoped to the signed-in parent account, messages thread, plan summary read from the school's billing record, top-up purchase flow).
- **billing/admin**: `SchoolPlan`, `PlanTier`, `Invoice`, `UsageStats` entities; `BillingRepository` (seat management writes, invoice history, usage aggregation) — school-admin role-gated.
- **role switching**: in the shipped app this is *not* a runtime toggle — a parent account and a student account are different signed-in identities (and a school-admin account a third). Model role as part of `AppUser`/`AuthSession` (already has provider/session shape in `auth/domain`), and router-redirect to the right shell based on it, the same way `app_router.dart` already redirects signed-out users.

## Design tokens

**Color** (light — seed-derived like the existing Material 3 theme, just extended):
- Brand: `#4A54E8` (primary), `#333DC9` (strong/hover), `#EDEFFE` (soft container)
- Success: `#1E9D6C` / soft `#E3F6EC` — Warning: `#B5720E` / soft `#FBF0DC` — Danger: `#D6455A` / soft `#FCE9EB`
- Ink: `#15161B` (primary text), `#50525F` (secondary), `#8A8CA0` (tertiary/faint)
- Surface: `#FFFFFF`, alt `#F6F7FB`, sunken `#EDEFF6`; border `#E4E6EF`

**Color (dark)**: brand `#8992FF` / strong `#A6ADFF` / soft `#252A57`; success `#3FCB90`; warning `#E3A23A`; danger `#F17685`; ink `#F1F2F7`/`#C4C6D6`/`#82849A`; surface `#1D1E27`, alt `#15161D`, sunken `#262733`, border `#33343F`.

**Radius** (card / control) per platform: iOS 20 / 14 · Android 16 / 100 (pill buttons) · macOS 12 / 8 · Windows 8 / 5.

**Type scale** (H1 / H2 / body) per platform: iOS 30 / 20 / 16 · Android 26 / 19 / 15 · macOS 22 / 16 / 13.5 · Windows 20 / 15 / 13.5. Use each platform's system font (SF Pro on iOS/macOS, Roboto on Android, Segoe UI Variable on Windows) — Flutter picks these up automatically per-platform if you don't override `fontFamily`.

**Elevation**: mobile cards use a soft shadow (`0 1px 2px rgba(20,20,45,.04), 0 10px 28px rgba(20,20,45,.07)`); desktop (macOS/Windows) cards are flat with a 1px border instead of shadow — more native to those platforms.

## Assets
No external images — all icons are simple custom-drawn line icons (24×24, `strokeWidth` ~1.8, generic geometric shapes: house, chat bubble, pencil, book, bar chart, people, envelope, shield, magnifying glass, cloud, lock, globe, checkmark/x circle, sliders, refresh arrows, paper plane, bulb, question-mark box, undo/redo arrows, trash, highlighter, download arrow, flag, share nodes, calendar, card, info circle, wallet, plus/minus, arrow-up-right, document, star, clock, window-caption glyphs). Recreate with your icon package of choice (`Icons.*` from Material, or a custom `CustomPainter`/SVG set) — none are borrowed from a specific commercial icon library. Lesson cover art is a placeholder gradient + icon; swap for real subject illustrations when available.

## Files
- `EduAI Redesign.html` — open this to click through the whole prototype (platform/role/appearance switcher included).
- `styles.css` — every design token and component style as CSS (colors, radii, type scale, per-platform chrome).
- `data.js` — mock content for every screen (schools/classes, tutor sample Q&A, lessons catalog, progress stats, parent children/messages/plan, admin plan/invoices/usage) — useful as a content/copy reference.
- `app.jsx` — root: role/platform/theme state, tab routing, desktop auto-fit-scale.
- `shell.jsx` — the adaptive chrome (iOS/Android tab bars, macOS toolbar segmented tabs, Windows title bar + tab strip, the shared "more" menu sheet).
- `ink-canvas.jsx` — the stylus drawing primitive (pressure-sensitive strokes, pen/highlighter/eraser, undo/redo) reused by Tutor's scratchpad, Workbook, and Lesson annotate.
- `screens-home.jsx`, `screens-tutor.jsx`, `screens-lessons.jsx`, `screens-progress.jsx`, `screens-parent.jsx`, `screens-admin.jsx` — every screen's markup/behavior.
- `icons.jsx` — the icon set (as inline SVG path data — reference for shapes, not for direct reuse).
- `frames/ios-frame.jsx`, `frames/android-frame.jsx`, `frames/macos-window.jsx` — device/window bezels used only to preview the design; not part of the shipped app.
