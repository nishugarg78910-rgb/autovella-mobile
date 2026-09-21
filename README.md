# Autovella Mobile

Flutter client for the Autovella CRM + PM + PSA platform. One codebase, two
targets: **Android** and **iOS**.

The web platform's UI is not ported. The information architecture, navigation
and every screen are designed for a phone; the **brand and theme are identical**
to the web product, taken from its own values rather than re-picked by eye.

---

## Brand provenance

The design tokens in `lib/core/theme/tokens.dart` were read off the live web
app (`:root` custom properties at `autovella.cloud`), not approximated:

| Token | Value | |
|---|---|---|
| `--brand-600` | `#2563EB` | primary |
| `--brand-700` | `#1D4ED8` | pressed / emphasis |
| `--bg-app` / `--bg-surface` / `--bg-muted` | `#F8FAFC` / `#FFFFFF` / `#F1F5F9` | |
| `--text-primary` / `secondary` / `tertiary` | `#0F172A` / `#475569` / `#94A3B8` | |
| `--border` / `--border-strong` | `#E5E7EB` / `#D1D5DB` | |
| radii | 6 / 8 / 12 px | |

Two deliberate departures, both documented in code:

- **Dark mode.** The web app ships none. Mobile users expect one, so the dark
  ramp is *derived* from the same slate/blue hues rather than invented — and
  brand lifts to `brand-400` in dark so it keeps contrast on a near-black
  ground.
- **Typeface.** The web stack is `'Inter', -apple-system, …, Roboto`. Rather
  than bundle Inter, mobile uses the platform face that stack already falls
  back to (SF Pro on iOS, Roboto on Android) — the native choice, and faithful
  to the declared stack. Swap via `fontFamily` in `app_theme.dart` if brand
  wants byte-identical glyphs.

> **Open brand question.** Three conflicting identities are in circulation: the
> live app (blue `#2563EB`, "PLAN. TRACK. ACHIEVE."), the logo asset (violet
> `#6E56F7` + teal `#14C9B6`, "One System. Every Workflow. Always Ahead."), and
> the marketing deck (a third blue, `#2F6BFF`). This app matches the **live web
> app** so users see one product. Worth resolving at brand level.

---

## Architecture

```
lib/
  main.dart                  async singletons → ProviderScope overrides
  app.dart                   MaterialApp.router, splash, text-scale clamp
  core/
    api/                     Dio client, endpoint map, error normalisation
    theme/                   tokens + Material 3 light & dark
    router/                  go_router, auth redirect, 5-tab shell
    widgets/                 design system (atoms, states)
    util/                    defensive JSON, formatting (INR, dates)
  models/                    domain models, parsed from real API payloads
  data/repository.dart       one generic REST repo, one line per module
  features/<module>/         screens + providers
```

- **State** — Riverpod. **Routing** — go_router. **HTTP** — Dio.
- **Auth** — session cookie, persisted to disk, so users stay signed in across
  restarts. A bearer token is also honoured if the backend returns one. Any
  `401` on any request drops the user to login.
- **Permissions** — `/auth/me` returns a per-module CRUD grid
  (`rolePermissions`). Modules a role cannot read are *hidden from navigation*
  rather than shown and then failing with a 403.
- **Plan gating** — the org's `featureFlags` hide modules the plan excludes.

### API

Base `https://autovella.cloud/api`, overridable at build time:

```bash
flutter build apk --dart-define=AUTOVELLA_BASE_URL=https://staging.example
```

Routes mirror the web app's own (`/projects`, `/tasks`, `/deals`, …). The
client unwraps the `{success, data}` envelope and tolerates endpoints that
return a bare array.

---

## Toolchain

Installed on this machine (Intel Mac, macOS 15.7.9):

| | |
|---|---|
| Flutter | 3.47.4 stable, at `~/flutter-sdk` |
| JDK | OpenJDK 17 (Homebrew), at `/usr/local/opt/openjdk@17` |
| Android SDK | `~/Android/sdk` — platform 36, build-tools 36.0.0, platform-tools |

The Flutter SDK is not on `PATH` by default. Every command below assumes:

```bash
export PATH="$HOME/flutter-sdk/bin:$PATH"
export JAVA_HOME=/usr/local/opt/openjdk@17
export ANDROID_HOME=$HOME/Android/sdk
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
```

## Running it

```bash
flutter pub get
flutter test                     # 25 unit tests
flutter analyze                  # clean

flutter run                      # device or emulator
flutter build apk --release      # universal APK for sideloading

# Interactive demo — the whole app on fixture data, no login, no backend:
flutter run -d chrome -t lib/demo.dart
```

## The Android build

A release APK has been built and verified:

| | |
|---|---|
| Output | `build/app/outputs/flutter-apk/app-release.apk` (59 MB, universal) |
| Package | `com.autovella.autovella_mobile` |
| Version | 1.0.0 (versionCode 1) |
| minSdk / targetSdk | 24 (Android 7.0) / 36 |
| Permissions | INTERNET, ACCESS_COARSE/FINE_LOCATION, CAMERA, READ_MEDIA_IMAGES |

It is a universal APK (all ABIs), so it installs on any Android phone. To
sideload: copy it to the device and open it, allowing "install from unknown
sources" for whichever app opens it. Or serve it over the LAN:

```bash
cd ~/Desktop/autovella-apk && python3 -m http.server 8080
# then browse to http://<your-mac-ip>:8080/Autovella.apk on the phone
```

For a faster, smaller build during development, target one ABI:

```bash
flutter build apk --release --target-platform android-arm64
```

### Signing

The release build is currently signed with the **debug** key (Flutter's default
template). That is fine for sideloading onto a phone; the Play Store needs a
real upload key. To add one, generate a keystore, put its details in
`android/key.properties`, and replace `signingConfig = signingConfigs
.getByName("debug")` in `android/app/build.gradle.kts`.

## The demo build

`lib/demo.dart` runs the *real* app — real screens, models, repositories and
routing — with a Dio interceptor (`FixtureInterceptor`) resolving every
request from `lib/demo/fixtures.dart` instead of the network. Fixture shapes
mirror live API payloads, so the real parsers are exercised. It carries a
`DEMO` banner so nobody mistakes it for their tenant.

This is also how the app can be shown to someone without giving them an
account, and how the UI gets visually reviewed without a backend.

---

## Module coverage

**Purpose-built screens** — Home (with live check-in), My Work, Projects +
detail (Overview / Tasks / Sprints / Team), Task detail (HTML description,
status change, checklist, comments), CRM (pipeline rollup, Accounts, Contacts)
+ Deal / Account / Contact detail, Timesheets (grouped into submittable weeks),
Time off, Expenses (camera receipt capture), Invoices (receivables rollup),
Attendance, Analytics, Calendar (agenda), Search, Notifications, Profile,
create/edit forms for tasks, projects, time entries and leave.

**Generic list screen** (`ModuleListScreen`) — Leads, Customers, Vehicles,
Inventory, Resources, Templates, Saved views, Bookmarks, Approvals, Roles,
Audit log, Automations, Recycle bin, Exchange rates, People, Teams, Holidays,
Sprints. These fetch their real endpoints and render live records; they are
schema-agnostic rather than bespoke, and each can graduate to its own screen
without touching anything else.

### Deliberately not on mobile

- **Gantt** — a dependency chart at 390pt is unreadable. The project Overview
  links out to the web app instead of shipping something nobody can use.
- **Org-wide settings, custom fields, import** — configuration work belongs on
  a desktop; `/settings` routes to Profile.

---

## Round 2 — security, depth and offline

### Field-level permissions (the important one)

Roles carry per-field grants alongside module CRUD:

```json
"tasks": { "read": true, "fields": { "actualHours": {"read": false, "edit": false} } }
```

`Permissions` now parses them and the UI enforces them. The rule that matters:
**an unlisted field stays visible.** The grid is an allow-list of
*restrictions*, not a schema — treating a missing entry as "deny" would blank
the app for every restricted role. `GuardedRow` / `GuardedField` /
`GuardedAction` (in `core/widgets/permission_gate.dart`) hide a field rather
than showing it disabled, because a greyed-out value still leaks the value.

### Offline writes

`OfflineQueue` persists writes that failed for network reasons and replays
them when connectivity returns. Deliberately **writes only** — reads already
fail with a retry, but a field engineer logging time in a basement should not
lose the entry.

Design notes worth keeping:
- Only *network* failures queue. A 400 is surfaced immediately, because it
  will never succeed on retry.
- A queued write is dropped after 3 non-network failures, so nothing retries
  forever behind the user's back.
- A slim banner shows offline state and the pending count; **Security & sync**
  lists each pending item and can discard one.

### App lock

Biometric / device-PIN lock after two minutes in the background, off by
default, switched on from **Security & sync**. `biometricOnly: false` on
purpose — wet hands and masks fail often enough that biometric-only would lock
people out of their own work. Enabling it requires passing the check first, so
nobody can enable a lock they cannot pass.

Android needs `FlutterFragmentActivity` (the default `FlutterActivity` crashes
`local_auth` at authenticate time) — `MainActivity.kt` was changed accordingly.

### Deep links from notifications

Notifications now carry a route payload. A tap while running pushes it; a tap
that *launches* the app is recovered via `getNotificationAppLaunchDetails()`
and replayed once the router exists — that cold-start path is the one that is
normally missed.

### New screens

- **Invoice detail** — lines (merged from `customItems`, `timeEntries`,
  `expenseEntries`), totals, payment progress, send and mark-paid.
- **Sprint detail** — progress, points, breakdown by status and by assignee,
  open and completed work.
- **Attachments** — image thumbnails with pinch-to-zoom preview, file rows
  that open externally, and camera/library upload. Embedded in task detail.
- **Security & sync** — app lock and the offline queue.
- **Timesheet submission** — a week can now be sent for approval; it could
  previously only be viewed.
- **Log time from a task** — with 0.5/1/2/4/8h presets, because the moment you
  finish a task is when you remember how long it took.

### Interaction

Swipe a task right to complete or reopen it. `confirmDismiss` returns false so
the row springs back rather than vanishing — a completed task stays visible and
struck through, which is what a checklist should do. Haptics on the checkbox
and the swipe.

## iOS

The iOS project is configured and ready — deployment target 15.0, bundle id
`com.autovella.autovellaMobile`, display name "Autovella", and all three
required usage strings (camera, photo library, location) present and the
plist validated with `plutil -lint`.

**It has not been built, and could not be built on this machine.** Two hard
blockers, both independent of effort:

1. **Disk.** Xcode needs roughly 40 GB installed. This Mac had 9.9 GB free
   before the Android toolchain went on, and under 3 GB after.
2. **Signing.** Even with Xcode, an `.ipa` that installs on a real iPhone
   needs an Apple Developer account (₹8,900/year), a signing certificate and a
   provisioning profile tied to your team. Those are account credentials — no
   amount of local tooling substitutes for them.

There is also a third, longer-term issue: **Flutter is deprecating Intel Mac
support** (`flutter doctor` warns about it on this machine). iOS builds will
need an Apple Silicon Mac regardless.

To build iOS, on an Apple Silicon Mac with ~60 GB free:

```bash
xcode-select --install && # then install Xcode from the App Store
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods
cd ios && pod install && cd ..
flutter build ipa                 # needs a signing team configured
```

## Device-testing round 1 — what was wrong and what changed

The first build was installed on a real phone. Most of what failed traced to a
single mistake: the endpoint map was inferred from the web app's *page* routes
rather than its *API* calls. The paths are now taken from the web bundle
itself (`/assets/dist/chunks/*.js`), which is the authoritative client.

| Symptom on device | Cause | Fix |
|---|---|---|
| Signed out on every launch | Auth is `Authorization: Bearer <token>`, not cookies. The token was held in memory only. | Token persisted in Keychain / Android keystore and reloaded before the first request. |
| No "remember me" | Not implemented. | "Keep me signed in" on the login screen, honoured by the token store. |
| Login had no logo, sat at the top | Placeholder Material glyph, top-aligned form. | Real brand lockup, vertically centred, max-width constrained. |
| Wrong logo throughout | A Material icon stood in for the mark. | Both brand artworks bundled (`logo_on_dark`, `logo_on_light`), theme-aware, and generated into the launcher icon. |
| **No way to mark attendance** | The card called `/attendance/today`; the real route is `/attendance/me/today`. On error the card returned an empty box, so it vanished entirely. | Correct route, plus the card never hides on error — it shows the state and keeps the button usable. |
| Attendance screen empty | A day is a `punches[]` array, not `checkIn`/`checkOut` fields. | `Attendance` rewritten around punches; multi-punch days sum correctly. |
| Invoices blank | Lines live in `customItems` / `timeEntries` / `expenseEntries`; there is no `lineItems`. Paid amount is `paidAmount`. | All three sources merged; correct field names. |
| People blank | `/auth/users` embeds base64 avatars (~190 KB each); 100 rows ≈ 19 MB. | Uses `/auth/users/directory`; shows name, job title and email. |
| Audit log would not open | Route is `/audit-logs` (plural); the singular 500s. Entries also carry avatars (~200 KB each). | Correct route, page size capped at 25. |
| Approvals errored | `/approvals` does not exist. | Rebuilt as a real screen aggregating pending timesheets, leave and expenses, with approve/reject. |
| Recycle bin showed rows with no info | Rows use `entityName` / `entityType` / `deletedByName`; the app read `name` and treated `deletedBy` as an object. | Correct fields, detail sheet, restore action, purge date. |
| Leads, Customers, Vehicles, Inventory, Operations | **None of these are endpoints on this platform.** | Removed. |
| Analytics thin | Only local data was used. | Adds `/analytics/summary`, `/analytics/kpis`, `/analytics/teams`, rendered generically so unknown response shapes still display. |
| Home looked blank | Three counters and a list. | Rebuilt: attendance, triage counters, approvals waiting on you, pipeline and receivables, today's work, and what is coming up. Each section fails independently. |
| No notifications | Not implemented. | Permission flow, settings screen, test notification, and polling that raises an OS notification for anything new on resume. |

Platform-side problems found along the way are written up separately in
[PLATFORM_AUDIT.md](PLATFORM_AUDIT.md) — they need backend changes.

### A note on failing quietly

Several of these were invisible rather than loud: a card that returned an
empty widget on error, a list that rendered "Untitled" for every row. The
attendance card is the clearest case — a wrong URL made the entire check-in
control disappear with no message. Sections now degrade *visibly*.

## Known gaps

1. **Endpoint shapes are inferred** for modules the MCP surface does not
   expose. Project, task, deal, account and contact payloads were verified
   against live data; invoices, expenses, timesheets, attendance, time off and
   the generic modules are modelled defensively (`J.pick` accepts several
   field spellings) but should be checked against real responses.
2. **`/vehicles`, `/inventory`, `/leads`, `/customers`, `/resources`** exist as
   web routes but are absent from the MCP tool surface — worth confirming they
   are live REST endpoints before relying on those screens.
3. **No push notifications.** The bell polls unread count on build. Real push
   needs FCM + APNs and a backend device-token endpoint.
4. **No offline write queue.** Reads fail gracefully offline; writes require a
   connection. A field-sales app in India probably wants queued writes.
5. **Subtask toggle** posts `{'toggle': true}` to the subtask endpoint — the
   platform has a dedicated toggle route that should be confirmed and wired.
6. **Attachments** are modelled but there is no file browser screen yet.
7. **Release signing** uses the debug key (see Signing above).

## Suggested next steps

1. Install the APK on a real phone and walk every screen against live data.
2. Build iOS on an Apple Silicon Mac with an Apple Developer account.
3. Generate a real upload keystore before any Play Store submission.
4. Resolve the brand conflict, then re-theme if the decision is violet/teal —
   it is a one-file change (`tokens.dart`).
5. Add push, then an offline write queue.
