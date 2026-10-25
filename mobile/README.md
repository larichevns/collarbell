# Collarbell mobile

Flutter app for iOS and Android: five tabs (Home, Today, Pets, Supplies, More),
English and Russian, sign-in through Firebase or a local developer account, an
API client generated from `contracts/openapi.json`, and a theme built from the
Collarbell design tokens.

M1 (pets and documents): the pets list with photos; adding and editing a pet
(details, identity colour, microchips and tattoos, photo); the pet's page with
the tabs Overview, Passport and Documents; the passport header and the
photographed passport pages; documents of photos and PDFs with a full-screen
page viewer.

M2 (care history and due dates): the pet's page gets a Health tab. Its care
plan is grouped into overdue, due soon (14 days), upcoming, and finished or
paused (folded), each row with its due date in the traffic-light colours and a
round "Done" button. Plans start from the server's presets for the pet's
species (36 codes, titles and notes translated by code) or from scratch; a
"last done" date gives the next due date. "Done" records what was given, with
photos of the sticker, and shows the next date before saving (worked out like
the server: the chosen date, else "valid until", else one interval later; a
one-off plan finishes). The history lists records newest first with a filter
by kind; records are added by hand from the paper passport, with the fields of
their kind. The Passport tab shows the health sections V–X built from the
records. Today lists the care of all pets that is overdue, due soon or due
later this month; a tap opens the pet's page on its Health tab, on top of
Today (pushed, not a jump to the Pets tab), so a form left open in the Pets
tab stays as it is and Back returns to Today.

M3 (AI scan): when the server has AI (`GET /ai/status`), the Passport tab
offers "Scan passport pages" and the Health tab a scan button beside "Add
past record"; without AI they are hidden, and typing records in works as
before. A scan takes up to 10 pages with the document scanner (VisionKit on
iOS, the ML Kit document scanner on Android: edges found, pages
straightened; shrunk to 2048 px JPEG on the phone) or from the photo library
(also where there is no scanner, e.g. a simulator). The pages upload, the
server starts reading them, and the copies on the phone are deleted; the
screen asks every 2 seconds until the draft is ready (usually 10–60
seconds), not while the app is in the background (back in front, it asks at
once). It can be left meanwhile: the Passport tab offers to pick the scan up
again, and shows a scan that failed with why, "Try again" (the same photos,
a new scan) and "Dismiss". The review loads the pet's plans and passport
afresh and lists the records, microchips and tattoos and the passport
details the AI found, ticked as the server suggests (entries saved already
or repeated on two photos unticked; one whose date couldn't be read can't be
ticked until the date is entered), with the AI's doubts on their values (a
day and month that could be swapped, with a one-tap swap on every date),
where each entry was read (the page, and the text as on it), and for a
record the plan it counts as "Done" of. A record the page gives no title is
named after its kind in the user's language ("Rabies vaccination" for one
against rabies). Passport details fill in empty fields; a value that differs
from the saved one is replaced only when its "Replace the saved value"
switch is on or the user changed it. Saving sends only the ticked entries,
as edited; the photos are kept as passport pages (a vet document's as a new
document) unless switched off. Leaving the review with changes asks first.
More → AI shows whether AI is set up (or "Couldn't check" with a retry), its
models, the free-tier warning, this month's use and a connection test.

M4 (reminders, feeding, visits): the pet's page gets a Feeding tab with its
schedules (times, days of the week, food and portion). Today starts with
today's feedings by time: each pet has a "Fed" button, "All fed" marks every
pet of that time, a mark shows when and by whom and can be taken back, a
long press skips a feeding on purpose (after asking); when someone else marked
it first, the app says who and when. Today reloads when the app comes back to
the screen, after midnight and when a push arrives. Then the planned visits (past ones ask how it went),
then the care that is due. Visits have a list, a form (kind, what for, date
and time in the household's time zone, pets, place, reminders a week, a day,
2 hours or an hour before) and a page with cancel, plan again, delete and
"The visit took place", which writes a care record for each pet and can mark
their plans of that kind done. Pushes work on Android: the app asks for
permission once, after the first feeding, visit or plan is saved, with a line
saying why (a refusal shows on Today and in the feeding form, with a way to
the system settings), registers the phone with the server (again when
Firebase gives it a new token), creates a notification channel per kind
(feeding, care, visits, other, and a quiet "who fed" that replaces a feeding
reminder once someone fed), shows pushes that arrive while it is open,
and opens the right screen when one is tapped (feeding → Today, care → the
pet's Health tab, a visit → the visit). Signing out forgets the phone on the server and drops its push token.
Android backups leave the app's local data out, so a restored phone gets an id
of its own.
More → Notifications shows whether pushes reach this phone (with a way to the
system settings when they are off, and a test push), turns kinds on and off,
and lists the coming and recent reminders with what happened to each. On an
iPhone it says pushes come later. Integration tests run with pushes off
(`DisabledPushPlatform`), so no permission dialog stops them.

M5 (supplies): the Supplies tab lists food, litter and medicine with how
long they last: what to buy now first (with "Bought"), then what runs out
within a week, the rest, and items no longer bought. An item's page shows
when it runs out and when to buy it (its delivery time before), "Bought"
(packages) and "Correct" (unopened packages and how full the open one is,
or "none left"), the feedings that use it, the shop link and the purchases
and counts, each of which can be taken back. The form takes kilograms and
litres; food is counted from the feedings that give it (the feeding form
has "Food from supplies", which locks the portion to the food's unit),
litter and medicine by "a package lasts N days". Adding by barcode uses
`mobile_scanner` (product codes only; the digits can be typed): an item
already in supplies offers "Bought", a product the databases know opens the
form with where the details came from, and what they don't know is read
from up to three photos of the package (camera or gallery) by AI. A
medicine offers a treatment plan with the interval printed on it. Today
lists what to buy, and a "time to buy" push opens the item.

Microchip scan: in the pet form, a microchip's number field has a scan
button. The camera (the same scanner page as supplies, with the codes chip
stickers carry) reads the barcode on the sticker in the passport and fills
in the number (two different chips in sight: the user picks one); a code
that isn't a chip's says so and scanning goes on.
"From a photo" (camera or gallery) looks for the barcode in the photo on
the phone first; a photo without one is read by AI on the server, which
fills in the number (and the place and date of the chip, where the card has
none), lets the user pick one of several, or says it found none. The card
says how the scan went until the number is typed. The number can always be
typed as before.

Shared households (groups): a person can be in several ("My home",
"Office"), as an owner, a member or a helper. The app shows one at a time,
names it in the `X-Household` header of every request and saves it per
account; Today shows it for people in more than one. Switching (More →
Switch group, joining with a code, or tapping a push of another group)
closes dialogs and builds every tab afresh, so no screen or data of the
other group stays; offline copies are kept per group. Changes are pinned to
the group they were started in (the group screen's, and forms', via
`inHousehold`), so a screen left open can't change another group. A 403 for
a group the user was removed from, or `/me` answering for another group,
takes the app back to their first one with a message and drops that group's
copies. The role is asked again on every sync, when the app comes back to
the screen and after a role refusal. More → Members and invites lists the
people with their roles; owners invite (the role, then an 8-character code
to share or copy, valid for 7 days), revoke invites, change roles (their
own after asking), remove people, rename the group, and delete it when they
are alone in an empty one; anyone can leave. Helpers see everything but only
mark (fed, "Done", the visit took place, bought, and take back their own
marks): the buttons to add, change, delete, scan or upload are hidden, from
one place (`HouseholdPermissions`). Sharing uses `share_plus`.

Plans (no payments yet): a group is on Free or Premium, which is given by
hand in the admin for now. More → Plan and the group screen open the plan
screen, above the tabs: the plan and until when, this month's AI photos
("7 of 20") with a bar, the day the count starts again, and on Free what
Premium gives; nothing can be bought in the app. AI reads at most the plan's
photos a month for the group, and on Free at most so many for one person in
all their Free groups: a passport, package or chip scan or the connection
test refused for that (409 `urn:collarbell:problem:ai-limit`, told apart by
its type from the 409 of "AI isn't set up") says how many are used or left
and when the count starts again, and the scans and the test offer the plan.
Too many AI requests in a row (429) say to wait.

Weight: the pet's page gets a Weight tab. It shows the latest weight large,
with its date, the change since the weight before it ("+0.2 kg since Sep 12")
and its body condition score ("BCS 5/9 · ideal 4–5"); a chart of the weight
over time (drawn with a `CustomPainter`: a line, a dot per weighing unless
they crowd, a hollow diamond per vet's weight, the lowest and highest weight
on the side, the first and last date below, a summary for screen readers),
with 3 months, 1 year and all time to choose from when the log is longer (the
last year first); and the history, newest first, each weight with the change
from the one before it. The history has the household's weighings (to the
gram, a body condition score on the 9- or 5-point scale if wanted, a note) and
the weights vets noted in check-up records, which open their record; a
weighing opens a bottom sheet to change or delete it (`POST
/pets/{id}/weights` with a request id, `PUT`/`DELETE /weights/{id}`). Helpers
only look. The Overview shows the latest weight with its date. A check-up
record saved anywhere (the form, "Done", a scan, a visit that took place)
reloads the log (`refreshCare`), and the scan review shows and edits the
weight a vet wrote for a check-up.

Quick text input: when the server has AI, the Health tab has "Write it in
words" next to the scan button (not for helpers). It opens a note: up to
1000 characters with a counter that counts as the server does (the note
trimmed, an emoji counting 2), an example in the user's language, a line
saying the keyboard's microphone can dictate it, and, before anything is
sent, the notes a scan shows (a draft only; the free Gemini tier, in a
note's words). "Read" checks it here as the server would (a letter or a
digit, not too long) and sends it (`POST /ai-imports` with source `Text`, a
request id per text, the same whenever that text is sent again); then the
wait and the review are a scan's, with the note quoted where a scan shows
its photos (on the review, with when it was written) and nothing to keep.
A note typed and not sent isn't left without asking (Back, iOS's back
swipe, tapping the tab again); otherwise they leave at once. The day's
notes used up (429 `urn:collarbell:problem:text-limit`, with the server's
`limit`, 30 by default) have their own message; the other failures read as
a scan's. Notes being read, ready or failed wait on the Health tab and
scans on the Passport tab, each listed apart (`?notes=true|false`, the
newest 20 of each); a note opens as a note even before it loads. A failed
one is read again ("Try again": a new note or scan naming it, `retryOf`,
which takes its place whoever started it; a note keeps the day it was
written) or dismissed, a note after asking. A review with changes isn't
left without asking either, by Back or by tapping the tab again. The
review of a scan or a note has a Weighings section: weights given without
an examination (a note's "weighs 4.2", an invoice's weight), each with its
day and where it was read, ticked as the server suggests (one in the log
already, given twice or refused by the weighing rules comes unticked, with
why), and an editor that checks it like the weighing sheet (to the gram,
above 0 and up to 200 kg, not in the future, not before an exact birth
date). Saving sends the ticked ones as weighings, reloads the weight log,
and the summary counts them.

Live updates: while the app is in front, it keeps a SignalR connection to
the server's hub (`/hubs/household`, WebSockets only, no negotiate), signed
in like its requests (the token in a header, never in the address) and
naming the group on screen (`X-Household`); it connects once the profile
sync is done. When someone else in the group changes something, the server
says what (`Changed` with topics such as `feeding`, `pets`, `household`) and
the app reads again the screens that show it, 300 ms of changes at a time;
a change made on this phone comes back with its own id (`X-Client`, random
per launch, sent with every request) and is skipped. A failed or dropped
connection is tried again after 1, 2, 5, 10 and 30 seconds, then every 30
seconds, each time as a new connection with fresh sign-in headers (the
package's own reconnecting is turned off: it would reuse the old token); a
refusal (not in the group any more, too many connections) is tried again
only when another group is shown or the app comes back to the front.
Connected again, the group's screens are read again, since the server keeps
no changes; without a connection, Today is read every 30 seconds. A moment
away (the camera, the photo picker, the share sheet, a permission dialog)
keeps the connection and reloads nothing; after 30 seconds in the
background it closes, pushes take over, and coming back reads the group's
screens once. The package
(`signalr_netcore`) sits behind `RealtimeClient` (`lib/data/live/`), so it
can be swapped without touching the screens; `lib/app/live_updates.dart`
decides when to connect and what to read again.

Home, onboarding and buttons (2026-10-14): the app opens on Home, the first
of five tabs. It greets by the time of day and shows the pets in a row (a tap
opens the pet on top of Home), "Right now" (the next feeding with the same
"Fed" and "All fed" as Today, what is overdue or due soon, the next visit,
what to buy) and, for those who can edit, quick actions as cards (a care
record, a visit, a passport scan and a note when the server has AI, a
weighing, a product scan; with several pets a sheet asks which). It is made
of Today's data (`todayProvider`), with no endpoint of its own, and reloads
as Today does (`TodayReload`). The onboarding (`/welcome`, above the tabs)
has three pages about the app, then for those who can edit the first steps:
a pet (name, cat or dog), its feeding times (08:00 and 19:00 to start),
notifications, and for owners an invite. Every step can be skipped; Back
walks back through steps and pages. Home opens it by itself once per
account on the phone (`onboarding.seen.<uid>`), and only for a person
starting from nothing: in one group, with no pets of any status, able to
edit; anyone else (a group with pets, two or more groups, as a family member
who joined keeps their own empty one; a helper) is marked seen without it.
It decides once the groups (`/me`) and the pets are loaded. More → Help
opens it again, which marks it seen too. Calls to action are real buttons: the main one filled, the others
outlined (a section header gets a compact outlined one, or a round outlined
"+" with a tooltip), and where several things can be started, action cards
(`CbActionCard`). Text stays for dialog answers, snackbar actions, escapes
("Skip", "Close") and links or edits inside text.

- Flutter 3.38.9 / Dart 3.10.8, Xcode 26 with CocoaPods, Android SDK 36.
- iOS bundle id and Android applicationId: `com.collarbell.app`.
- iOS 15+ (required by Firebase), Android API 24+.

## Configuration

Values come from `--dart-define`:

| Define | Values | Default |
|---|---|---|
| `CB_API_BASE_URL` | API origin, `http(s)://host:port` | `http://localhost:5080` |
| `CB_AUTH_MODE` | `dev` or `firebase` | `dev` in debug builds, `firebase` in profile and release builds |
| `CB_APP_EVENTS` | `true`: a debug build reports to the visor too (below) | off in debug builds; profile and release builds always report |

## Run in dev mode against the local API

Dev mode needs no Firebase. The sign-in screen shows "Continue as developer"
with an editable email. The user id is derived from the email
(`dev-` + FNV-1a-64 of the lower-case email), so the same email is the same API
user on every simulator and phone. Requests carry `X-Dev-User: <uid>` and
`X-Dev-Email: <email>`; the API accepts these headers only in the Development
environment. The email and password form also works in dev mode, but passwords
are not checked.

Start the API first (see `backend/`), then from `mobile/`:

```sh
flutter pub get

# iOS simulator: the Mac is localhost
flutter run --dart-define=CB_API_BASE_URL=http://localhost:5080

# Android emulator: the Mac is 10.0.2.2
flutter run --dart-define=CB_API_BASE_URL=http://10.0.2.2:5080

# Physical phone on the same Wi-Fi: the Mac's LAN IP
ipconfig getifaddr en0          # e.g. 192.168.1.23
flutter run --dart-define=CB_API_BASE_URL=http://192.168.1.23:5080
```

For a physical phone the API has to listen on all interfaces, not only
`localhost`: the AppHost's `phone` profile does that (see "Install on your
phone" below), and the macOS firewall has to let the port through. On an
iPhone, allow "Local Network" access when iOS asks. Plain HTTP is allowed in
debug builds and in builds whose `CB_API_BASE_URL` is `http://`
(`usesCleartextTraffic` in `android/app/build.gradle.kts`); other release
builds are HTTPS only.

After sign-in, and on every start with a saved session, the app sends the
device time zone (IANA, e.g. `Europe/Berlin`) and the UI language (`en` or
`ru`) with `PUT /api/v1/me`; failures are ignored. The Pets tab then loads
`GET /api/v1/pets`.

Photos and PDFs come from the API as signed links to the object storage
(SeaweedFS on `http://localhost:8333` locally), valid for 15 minutes. The iOS
simulator reaches them as they are. For an Android emulator or a phone, the
API has to sign links for an address the device can reach: set
`Storage__PublicEndpoint` for the API, e.g. `http://10.0.2.2:8333` or the Mac's
LAN address.

## Install on your phone

For everyday use the app runs as a release build on an Android phone and
talks to the server (`https://collarbell.example.com`, see
`deploy/README.md`). From the repository root, the phone on a USB cable:

```sh
sh mobile/tool/install_phone.sh
```

The script builds a release APK for arm64 with that address and Firebase
sign-in, installs it with `adb install -r` (the app keeps its data), and stops
Gradle afterwards. The phone needs Developer options → "USB debugging";
Xiaomi phones also "Install via USB", and they ask for a tap on the phone for
every install.

To try a change on the phone before it is deployed, run the API on the Mac in
phone mode (from `backend/`: `dotnet run --project src/Collarbell.AppHost
--launch-profile phone`; reachable over Wi-Fi, dev sign-in off) and pass its
address: `sh mobile/tool/install_phone.sh http://<the Mac's Wi-Fi address>:5080`.

The Android build is kept to 3 GB of memory (`android/gradle.properties`):
the Mac it runs on is shared with other projects.

### On an iPhone

The iOS app builds and runs (checked on the simulator: `flutter build ios
--simulator --debug`). Without the paid Apple Developer Program it gets no
push reminders (the app says they come later; Today shows what is due) and no
TestFlight, but it can be put on your own iPhone for free:

1. Open `mobile/ios/Runner.xcworkspace` in Xcode, sign in with your Apple ID
   (Xcode → Settings → Accounts), and under Runner → Signing & Capabilities
   pick your personal team. Xcode may ask for a unique bundle id if
   `com.collarbell.app` is taken by another team.
2. Connect the iPhone by cable, trust the Mac, and turn on Developer Mode on
   the phone (Settings → Privacy & Security).
3. From `mobile/`:
   `flutter run --release -d <the iPhone> --dart-define=CB_API_BASE_URL=https://collarbell.example.com --dart-define=CB_AUTH_MODE=firebase`
4. On the phone, trust the developer once (Settings → General → VPN & Device
   Management). An app signed with a free team runs for 7 days; then run step 3
   again.

## Without a connection

Sometimes the server is out of reach: no mobile internet, a weak signal. The
app keeps the last answer of each GET the
screens read (`lib/data/api/offline_cache.dart`: one file per answer in the
app's own storage, per signed-in user, cleared on sign-out) and shows it when
the server doesn't answer, with a strip "No connection to the server · data
from 14:05" above the tabs (`lib/app/offline_banner.dart`). A live answer
always wins. Changes are never made on top of copies: while the server
doesn't answer, a change isn't sent; the app checks whether the server is
back first, and if so reloads every screen and asks to try again. The strip
checks the server every 20 seconds and when the app comes back; once it
answers, every screen reloads. Edit forms opened from a copy don't save. A
server in the local network (the API on a developer's Mac) gets 3 seconds to
connect, others 10.

Content loads as a skeleton (`CbLoadingState` in
`lib/shared/widgets/state_views.dart`): grey rows for a list, grey fields for
a form, with a soft shimmer, still when the phone asks for less motion. A
spinner (`CbLoadingState.spinner()`) is left for waits that aren't content,
such as the camera or AI reading.

Forms ask "Leave without saving?" when Back would lose what was typed
(`lib/shared/widgets/leave_guard.dart`): each form compares its values with
those it opened with.

## What the app tells the server (the visor)

For support, the app tells the server what it did and saw, for the admin's
"визор" (`lib/data/api/app_events.dart`); the server keeps it for 7 days.
Every request carries `X-App-Session` (a random id of this launch, never
saved) and `X-App-Version` (`appVersion` in `lib/data/api/app_session.dart`,
which a test keeps equal to pubspec's version). Reports go to
`POST /api/v1/events`: the screens opened, by their route's pattern
(`/pets/:petId/edit`, tab switches too), ten actions by a fixed name (`fed`,
`fed-all`, `done`, `visit-took-place`, `bought`, `pet-saved`,
`scan-started`, `invite-created`, `joined-group`, `group-switched`), the
error messages shown (their kind, status, problem type and trace id) and
crashes (the exception's type and up to five lines of the app it went
through). Never what the person typed, no names or ids, no messages. They
wait in memory (at most 200) and go every 30 seconds, as soon as 20 wait,
and when the app goes to the background, 50 a request and at most 5 requests
a minute; a batch that fails is sent once more, then dropped. Only while
someone is signed in: signing out drops what waits. The reports pass by the
offline copy, so they never show the banner. Debug builds and tests send
nothing unless built with `--dart-define=CB_APP_EVENTS=true` (tests turn it
on with `appEventsOnProvider`).

## App icon

The icon is drawn in `tool/icon/`: `foreground.svg` (a collar and its bell),
`monochrome.svg` (the same in one colour, for themed icons on Android 13+) and
`icon.svg` (both on the dark green #066849, for iOS; the icon keeps it while
the app's `primary` is the bright #00B53F). After changing a drawing, run
`sh tool/icon/make_icons.sh` (needs `brew install librsvg imagemagick`) and
commit the PNGs it writes. Android 8+ gets an adaptive icon
(`res/mipmap-anydpi-v26/ic_launcher.xml`), older Android a round one. The
status bar icon of notifications (`res/drawable/ic_notification.xml`) is the
same bell.

## Firebase sign-in

Firebase is set up: project `collarbell-3e2b9`, Email/Password sign-in. The
config is committed, so there is nothing to do after cloning. To sign in with
real accounts in a debug build (release builds always do):

```sh
flutter run --dart-define=CB_AUTH_MODE=firebase --dart-define=CB_API_BASE_URL=http://localhost:5080
```

Requests then carry `Authorization: Bearer <Firebase ID token>`, and the API
accepts tokens of this project only. Details, including how to re-run
`flutterfire configure`, are in the [root README](../README.md#firebase-sign-in).

## Code layout

```text
lib/
  main.dart               runCollarbell(): reads AppConfig, initialises Firebase (firebase
                          mode only), runs the app; integration tests pass provider overrides
  firebase_options.dart   Firebase project config, generated by flutterfire configure
  app/                    MaterialApp.router, go_router with the auth redirect and the pet
                          routes, tab shell, AppConfig, settings (theme, language), live
                          updates (live_updates.dart: when to connect, what to read again)
  data/api/               ApiClient (dio, auth headers, send() → ApiException), RFC 7807,
                          the date converter for `format: date`, the X-Household header,
                          the launch's ids (X-App-Session, X-Client), the offline copies
    generated/            GENERATED from contracts/openapi.json: retrofit clients and models
  data/live/              RealtimeClient (the live connection, as the app sees it) and its
                          signalr_netcore implementation
  features/
    auth/                 AuthRepository, Firebase and dev implementations, sign-in screen
    me/                   MeRepository, the profile sync after sign-in, /me with the groups
    household/            groups and roles: the group on screen (saved per account) and
                          what the role may do, HouseholdRepository, the group screen,
                          invites, joining with a code
    billing/              the group's plan (Free or Premium) and this month's AI photos:
                          BillingRepository, the plan screen, the "See the plan" button
    pets/                 Pet, PetsRepository, list, form (with chips and tattoos),
                          pet page with tabs, Overview tab, chip/tattoo rules
    care/                 care.dart (plans, records, presets), care_rules.dart (next due
                          date, groups, fields per kind), care_labels.dart (words and icons),
                          CareRepository and its providers, refreshCare, the Health tab,
                          preset picker, plan form, Done screen, record form and detail,
                          widgets/ (plan and record rows, due line, Done button, photos,
                          vaccine target chips)
    home/                 Home (the first tab) and the pet picker of its quick actions
    onboarding/           when the onboarding opens by itself, and its screen
    today/                TodayCare, TodayRepository, the Today screen, its first steps
                          (also on Home) and TodayReload (Home and Today)
    passport/             passport header (repository, Passport tab, form), passport pages,
                          the health sections V–X
    documents/            PetDocument, DocumentsRepository, Documents tab, form, detail
    weight/               weight.dart (the log, body condition score, periods, limits),
                          WeightRepository and its provider, refreshWeight, the Weight tab,
                          the weighing sheet, widgets/weight_chart.dart (the CustomPainter)
    ai/                   ai.dart (AI status, scans, drafts), AiRepository and its providers,
                          the AI screen (More → AI), the scan screen (pages, upload, wait),
                          scan_review.dart (the draft as the user leaves it, its rules, what
                          a save sends), the review screen, the entry editors, refreshAfterScan,
                          widgets/ (the entry points, the resume and failed-scan cards, the
                          entry cards, AiStatusRefresher)
    files/                StoredFile, FilesRepository (upload, fresh links), MediaPicker
                          (camera, library, PDF, document scanner and its page shrinking),
                          page viewer, image and page widgets
    today/ supplies/ more/
  l10n/                   app_en.arb (template), app_ru.arb, generated AppLocalizations
  shared/                 card, action card, header, notice, section, text and date fields, save bar,
                          confirm dialog, empty/error/loading states, error messages
  theme/                  tokens.g.dart (generated), ThemeData, theme extensions, fonts
tool/generate_api.sh      regenerates data/api/generated
```

State is Riverpod 3 without code generation. Riverpod's automatic retry is
turned off (`ProviderScope(retry: noAutomaticRetry)` in `main.dart`): screens
show the error with a "Try again" button instead.

Screens never touch the API directly: they call repositories
(`PetsRepository`, `PassportRepository`, `DocumentsRepository`,
`FilesRepository`, `MeRepository`, `CareRepository`, `TodayRepository`,
`AiRepository`, `HouseholdRepository`...). Each repository has an `Api…`
implementation over the generated client and maps its models (imported with
the `dto.` prefix) to the app's own classes; widget tests replace the
repositories with fakes. Picking photos and PDFs goes through `MediaPicker`
(`mediaPickerProvider`) for the same reason.

Rules that keep data safe:

- Document pages change one at a time (`POST /documents/{id}/pages`,
  `DELETE /documents/{id}/pages/{fileId}`); editing a document changes only
  its details. The app never sends a whole page list, so a screen working
  from an old copy can't drop pages added elsewhere.
- Code that refreshes data after an `await` takes the `ProviderContainer`
  (`ProviderScope.containerOf`) before the first `await`: the screen's `ref`
  stops working once the user leaves it. Forms can't be left while they save
  (`PopScope`).
- Forms build all their fields (no lazy lists), so a save checks every field
  and scrolls to the first one with an error. A retry reuses files that
  already uploaded.
- Record photos are also added and removed one at a time
  (`POST /care-records/{id}/files` with one file id,
  `DELETE /care-records/{id}/files/{fileId}`). Saving a record sends its
  details, then deletes the removed photos, then adds the new ones, so a
  full record (10 photos) can swap one; removing a record's last photo
  doesn't delete the record (documents, where it does, add first).
  Attaching a file that is already on the record (a retry after a lost
  response) is no error.
- "Done" uploads the photos first, then marks the plan done, then attaches
  the photos to the new record. Each Done screen makes one `requestId` (a
  UUID) and sends it with every try: the server answers a retry after a lost
  response with the first result, and marks a plan done once per day anyway.
  Adding a plan or a record works the same way (one `requestId` per form;
  none on edits), and a record that saved but whose photos failed is
  updated, not added again, on the next save.
- When a save fails, the plan, record and Done forms still reload the
  plans, history, passport sections and Today, because the save may have
  gone through with only the answer lost. A plan or record deleted on
  another device (404) closes the form with a message.
- While a form saves, its fields take no input (`IgnorePointer`, and the
  Done screen turns its fields off): a menu or a date picker opened then
  would be closed by the save instead of the form. The date and time fields
  drop a value picked after their screen closed.
- The Done form fills in the plan's usual product and sends what the field
  says: a cleared product means none (the server no longer substitutes the
  plan's).
- After any care change, `refreshCare` (through the container) reloads the
  pet's plans, history and passport sections and Today.
- A scan uploads its pages once: a retry reuses the ones that uploaded.
  Each scan the user starts has one `requestId`, sent with every retry, so
  a lost answer never starts it twice; "Try again" after a failed scan is a
  new scan (a new id) of the same photos, and the server drops the failed
  one. Uploading and starting can't be left (`PopScope`); waiting for AI
  can, the server goes on. The scanner is asked for one page more than a
  scan takes (the iOS scanner drops extra pages silently), so more pages
  show and only the first 10 are used. Pages on the phone are deleted once
  the scan starts, on "Scan again" and when the screen closes.
- AI never saves anything itself: the review's changes stay on the phone
  until "Save", which sends only the ticked entries. The server answers a
  scan saved before with the first result, so a save whose answer was lost
  (no connection, a timeout, a server error) is checked with
  `GET /ai-imports/{id}` before anything else: saved — the review closes
  with what was saved; not saved — it stays editable; unknown — the next
  save asks first. Otherwise a second save would get the first one's answer
  and drop the changes made since. "Discard" on a scan that turns out saved
  (409) says so. The server's field errors
  (`records[2].record.performedOn`, `identifiers[0].code`,
  `passport.issuedOn`) name entries by their place in the request; the
  review remembers which entry it sent at each place and shows the error on
  it. After a save, `refreshAfterScan` reloads the care, every open plan,
  the pet, the passport, the documents and the pet's scans.
- Whether the server has AI is asked again after that failed (no connection
  at start), when the app comes back from the background or the Passport,
  Health or More screen is shown again (`AiStatusRefresher`).
- The AI connection test can take minutes (the server tries the models in
  turn), so `/ai/test` has its own 3-minute receive timeout
  (`AiTestTimeoutInterceptor`); other requests keep 20 seconds.
- Plans and records with a value this app doesn't know (a newer kind,
  interval unit or vaccine target) are shown with stand-ins and can't be
  edited, because the API would replace what the app can't show; they can
  still be deleted and marked done. Editing a plan sends `active` only when
  the user changed it (null keeps it). A field that doesn't belong to a
  record's kind is still shown when the record has a value in it, so saving
  never drops it unseen.

## API client

The client is generated from `contracts/openapi.json` (written by the backend
build) with [swagger_parser](https://pub.dev/packages/swagger_parser):
retrofit clients over the app's dio instance and json_serializable models.
The output in `lib/data/api/generated/` is committed. After the contract
changes, regenerate and commit:

```sh
sh tool/generate_api.sh   # from mobile/
```

The script empties the folder (except its README), runs `dart run
swagger_parser` (settings: `swagger_parser.yaml`) and `dart run build_runner
build --force-jit` (settings: `build.yaml`; AOT compilation of the build script
fails on Dart 3.10 because some plugins have build hooks). CI runs the same
script and fails if the result differs from the committed files.

How the contract's OpenAPI 3.1 constructs come out:

- `type: ["null", "string"]` and `oneOf: [{type: null}, {$ref}]` become
  nullable Dart types, as they should.
- Records list all their fields as `required`, so the constructors of request
  models need every field, null included; that matches the API (null means
  "not set" or "keep").
- `format: date` would be sent as a full timestamp, which the API rejects
  with 400. `field_parsers` in `swagger_parser.yaml` applies
  `DateOnlyConverter` to every `DateTime?` field and `RequiredDateOnlyConverter`
  to every `DateTime` one (a plan's `nextDueOn`, a record's `performedOn`),
  which send `2021-04-03`. The required timestamps of responses (`createdAt`,
  `expiresAt`) get the converter too, harmlessly: reading accepts both forms
  and responses are never sent back.
- The multipart upload (`IFormFile`, binary) takes a dio `MultipartFile`
  (`use_multipart_file: true`).
- `sizeBytes`, `width` and `height` are "integer or string" in the contract
  (ASP.NET Core accepts numbers in quotes), which swagger_parser can only type
  as `dynamic`; `storedFileFromDto` reads them as `int`.
- Enum values the app doesn't know (from a newer server) become `$unknown`
  instead of failing, and the repositories map them to a default.

## Packages

Added in M1, the newest versions that support Flutter 3.38 / Dart 3.10:

| Package | Version | For |
|---|---|---|
| retrofit | 4.10.0 | generated HTTP clients over dio |
| json_annotation | 4.9.0 | generated models (4.10+ needs a newer analyzer than Flutter 3.38 allows) |
| image_picker | 1.2.3 | camera and photo library, resized to 2048 px, JPEG quality 85 |
| file_picker | 13.1.0 | PDFs for documents |
| cached_network_image | 3.4.1 | photos cached on disk by file id (4.x needs Flutter 3.44) |
| url_launcher | 6.3.2 | opens PDFs in the system viewer |
| uuid | 4.6.0 | (M2) request ids that make "Done" and new records safe to retry |
| cunning_document_scanner | 3.0.3 | (M3) the document scanner: VisionKit on iOS, the ML Kit document scanner on Android; pages as JPEG |
| flutter_image_compress | 2.5.1 | (M3) shrinks scanned pages to 2048 px, JPEG quality 85, upright and without EXIF (on iOS it brings the SDWebImage pods) |
| share_plus | 13.3.1 | (groups) the phone's share sheet for an invite code |
| signalr_netcore | 1.4.4 | (live updates) the SignalR client, pure Dart, behind `RealtimeClient`; its own reconnecting is turned off |
| swagger_parser (dev) | 1.45.0 | generates the client from OpenAPI |
| build_runner (dev) | 2.15.1 | runs the generators (2.16 needs Dart 3.11) |
| retrofit_generator (dev) | 10.2.9 | retrofit code |
| json_serializable (dev) | 6.11.2 | model code |

iOS asks for camera and photo access with the texts in `ios/Runner/Info.plist`
(English) and `ios/Runner/ru.lproj/InfoPlist.strings` (Russian); the
document scanner uses the same camera text, and its own screens follow the
phone's language. Android needs no permissions: the camera and the photo
picker run as system activities, the ML Kit document scanner runs in Google
Play services, and its fallback on phones without them uses the system
camera. The scanner needs Android API 24 (the app's minimum) and iOS 13.

## Design tokens and theme

`design/tokens.json` is the source. Regenerate the Dart tokens after changing it:

```sh
python3 tools/gen_flutter_tokens.py           # from the repo root
python3 tools/gen_flutter_tokens.py --check   # CI: fails if tokens.g.dart is stale
```

In widgets: `context.cb.inkMuted` (colours), `context.cbText.displayLg` (type
scale), `context.cbShadows.card`, and `CbSpace`, `CbRadius`, `CbSize` for
dimensions. Rules: light theme by default; white screens with a blue-grey
interface. The green has two shades: `primary` (bright #00B53F) is only a
fill — the filled buttons and the FAB (white bold words on it), switches,
radios, progress — and `primary-text` (darker #007F2B) is every green word,
small green icon and thin green line on white or mint: text buttons, the
selected tab, chip, segment and navigation item, the focused field;
`accent` (yellow) is only a fill, never text on white: "soon", "time to buy"
and "check this" are a `CbStatusTag` (yellow pill, dark text and icon), and
overdue or ran out is the red one; `danger` (red) is only for overdue items,
errors and deleting, always with an icon and words. Every button and input is
`CbSize.controlMd` (44) high, chips `controlSm` (36); outlines are
`CbSize.borderWidth` (1.5) in `line-strong`. Buttons side by side are 8 apart,
stacked 12 as seen, which is a `SizedBox` of 8: each 44-high button has 2 px of
its 48-px touch area above and below. Inputs are 44 high too, with their
words 16 in from the left and a trailing icon (or a dropdown's `expand_more`,
`cbDropdownIcon`) 16 in from the right. A text button left in line with text
(an inline "Change") has no side padding (`cbInlineTextButtonStyle`), so its
words share the text's edge; a `CbSection` action is a compact outlined button
(`cbCompactOutlinedButtonStyle`). Body text of 16 px or more. One filled (primary) button per screen.
Pets have no colours of their own: the avatar is the photo or the initial on
the neutral `avatar` circle.

Icons: Material Symbols Rounded from the `material_symbols_icons` package
(pinned), `Symbols.<name>_rounded`, the same family the web app draws. The
theme draws them outlined at weight 400 for the 48-px optical size (`CbIcons`
in `lib/theme/collarbell_theme.dart`): a little thinner than Material's usual
icons, as the web's. A filled glyph is the same icon with `fill: 1` (the
selected navigation tab, the "done" check). `collarbell_theme.dart` exports
`Symbols`, so a screen that imports the theme has them. Release builds keep
only the glyphs the code uses (icon tree shaking needs `const` icons).

Fonts: Helvetica Neue on iPhone and Mac (a system font, nothing bundled),
Arimo elsewhere (the free twin of Arial, same widths), and JetBrains Mono for
chip numbers and codes (`lib/theme/cb_fonts.dart`). Arimo and JetBrains Mono
ship in `assets/google_fonts/` and are declared under `fonts:` in
`pubspec.yaml`, so text never flashes in a fallback font and the app works
offline. Only the weights 400, 500 and 700 exist; never use 600. The OFL
texts are registered for the licences screen (`main.dart`).

Russian texts keep short words off the end of a line with non-breaking
spaces: after changing `app_ru.arb`, run `python3 tools/typograph.py` from
the repository root (CI runs it with `--check`).

## Localization

Strings live in `lib/l10n/app_en.arb` (template) and `app_ru.arb`. The Dart
code is generated into `lib/l10n/` by `flutter pub get`, `flutter run` or
`flutter gen-l10n` (Flutter 3.38 has no synthetic `flutter_gen` package).
Access strings with `context.l10n`.

Copy rules: English in sentence case; Russian with the formal «вы» in lower
case; no emoji and no exclamation marks; household actions without gendered
verbs ("Fed by Anna · 08:02", «Покормлено · Аня, 08:02»).

## Checks

```sh
flutter analyze
flutter test
flutter build ios --simulator --debug
flutter build apk --debug
```

Widget tests (`test/`) run screens with fake repositories and a fake media
picker: `test/helpers/pump.dart` has `pumpScreen` for one screen and `pumpApp`
for the whole app at a route (e.g. `/pets/p1`), signed in as a developer.

End-to-end tests run on a simulator against the local API and save
screenshots to `build/screenshots/`:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/pets_passport_test.dart -d <simulator id> \
  --dart-define=CB_API_BASE_URL=http://localhost:5080
```

`pets_passport_test.dart` signs in as `e2e-pets@collarbell.local`, adds the
pet Murka, adds a passport page (a picture drawn at runtime instead of the
camera), checks the Passport and Documents tabs and deletes the pet again.
`care_test.dart` (`e2e-care@collarbell.local`) adds the cat Barsik, plans a
deworming from a preset with a "last done" date so it is due soon, sees it on
Today, marks it done there with a photo (it leaves Today), adds a past rabies
vaccination and finds it in the passport's section V, and deletes the cat
(screenshots `41`–`51`). `care_ru_test.dart` (`e2e-care-ru@collarbell.local`)
switches the app to Russian, fills plans and records through the
repositories and photographs each care screen (`60`–`70`); run it on a small
simulator, e.g. an iPhone SE (3rd generation). `smoke_test.dart` and
`firebase_smoke_test.dart` check sign-in. Shared helpers (drawn pictures,
date picking, cleanup) are in `integration_test/helpers.dart`.
`ai_scan_test.dart` (`e2e-scan@collarbell.local`) needs the local API with
AI (the Gemini key in the AppHost's user secrets): it gives the cat Barsik
a rabies plan, scans a passport page drawn at runtime (instead of the
scanner), waits for the real AI (up to three minutes), checks that the
review links the vaccination to the plan, saves it, and finds it in the
history with the plan moved to the vaccine's "valid until"; on the way it
photographs the review in Russian with the dark theme and runs the AI
screen's connection test (screenshots `80`–`89`).

## Troubleshooting

- **iOS: "Unable to find a destination matching the provided destination
  specifier" / "iOS 26.5 is not installed"**, or storyboards failing with
  "iOS 26.5 Platform Not Installed". Xcode needs the simulator platform that
  matches its SDK (an older simulator runtime is not enough). Install it with
  `xcodebuild -downloadPlatform iOS` or Xcode → Settings → Components.
