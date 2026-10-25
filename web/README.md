# Collarbell on the web

Collarbell for pet owners on a big screen, at **<https://collarbell.example.com/app/>**: the same product as
the phone app, with the same accounts, households and API. English and Russian.

What it does:

- **Sign-in** with the e-mail and password of a Collarbell account (Firebase, as in the app), "Forgot password?".
  Accounts are made in the phone app; the sign-in page says so and links to the landing.
- **Home** (`/app/`, where the app opens): a greeting by the time of day, the pets (each opens its page; "Add" for
  those who add pets), **"Right now"** from Today's data (the next feeding with "Fed" working as on Today, how much care
  is overdue and due soon, the next visit, what to buy; "All done for today" when nothing is left; the first steps when
  nothing is set up) and **quick actions** for all but helpers (a vaccination or treatment, a visit, a passport scan and
  a note with AI, a weighing, a new item in supplies; one pet goes straight to it, several ask "Which pet?"). No pets
  yet: "Add a pet" and the tour.
- **Getting to know the app** (`/welcome`): three pages (reminders come to the phone app; the passport from photos;
  the family), then for those who add things the first steps: a pet (name and cat or dog), its feeding times (8:00 and
  19:00 to start with) and, for owners, an invite. Every step can be skipped, and Back goes to the step before. It opens
  by itself once per account on this browser, from Home, only for someone new: in one household, with no pets at all,
  who can add them (a family member who joined, whose own empty household may be on screen, never gets it); Settings
  → Help opens it any time, and that counts as its turn too.
- **Today** (`/app/today`): feedings by time with "Fed", "Skip", "All fed" and taking a mark back; visits, with "The
  visit took place"; what to buy, with "Bought" (one package); care that is overdue, due soon or due later, with
  "Done". Nothing planned yet: action cards for the first steps.
- **Pets**: the list; adding, editing and deleting pets (a microchip's number can be read from a photo of its sticker:
  one number fills the card, two or more are picked from); a pet's page with six tabs, each at its own address:
  - **Overview**: the photo (drop a picture onto it, or pick one), details and microchips.
  - **Health**: the care plan by status (overdue, due soon, upcoming; finished and paused folded) with "Done"; plans
    from the ready-made ones for the species or by hand, changed, paused, deleted; the history newest first with a
    filter by kind; records by hand with every field of their kind, and their photos and PDF files (drop them onto
    the record); **a passport's history in bulk**: a table where each row is a record, checked row by row and
    saved one request per row; and, when the server has AI, **"Scan a vet document"** and **"Write it in words"**
    (see AI below).
  - **Passport**: its details (model, number, country, date of issue, the vet who issued it, owners), the photographed
    pages (drop several at once, view them large, delete one), the health sections V–X, the note that the digital
    copy is for information only; **"Scan passport pages"** when the server has AI.
  - **Documents**: by type; drop scans, photos or PDF files to make a document of them, in that order; pages large with
    the arrow keys, a PDF in a new tab; pages added and removed; details changed; documents deleted.
  - **Feeding**: the schedules (times, days, food typed or from supplies, portion, paused) and their form.
  - **Weight**: the latest weight and its change, a chart (a dot per weighing, a hollow diamond per vet's weight; 3
    months, 1 year or all time once the log is longer), the history, the weighing dialog.
- **AI scans and notes**, as on the phone: up to 10 photos of passport pages or of a vet's paper (iPhone's HEIC
  photos are turned into JPEG where the browser can open them, upright, while the drop zone waits; a PDF is refused
  with a word to send a screenshot), or
  a note in words of up to 1000 characters, go to AI after a word that the server uses Gemini's free tier. While it
  reads (seconds, sometimes minutes), the scan waits as a card on the Passport or Health tab; when ready, its page
  shows the photos or the note beside the draft: records, weighings, microchips and the passport's details, each with
  a tick, the AI's doubts highlighted (day and month swapped, unreadable, in the future, ending before it starts,
  repeated, a bad number, already saved, differing from what's saved), an editor with the rules of the record form,
  and a record's link to the plan it is the "Done" of. Duplicates come unticked. "Save selected" saves what is ticked
  in one go, with the photos kept as passport pages or not, and says what was saved. A scan saved or thrown away
  (here, or on another device) shows so when its page opens again, never its review from an old copy: saving it again
  would save nothing. A scan that failed says why, with "Try again" (it reads the same photos or text again in its
  place; opened again after that started, the new scan opens) and "Dismiss" (after asking). The month's photos of the
  plan, the day's notes and the server's pace are said before or when they run out; AI not set up (any more) makes its
  buttons go.
- **Visits**: planned and past, adding, editing, cancelling, deleting, "The visit took place".
- **Supplies**: food, litter and medicine grouped as on the phone (to buy, running out soon, in stock, no longer
  bought), each with its estimate ("about 6 days"); "Bought" in packages and "Correct the stock" (unopened packages
  and how full the open one is, or "None left"); an item's page with its forecast, the feedings that give it, its
  details and its purchases and counts, each of which can be taken back (helpers only their own); adding and changing
  an item: its kind, the package in grams or kilograms, millilitres or litres, a food's energy, the daily use from the
  feedings or by hand ("a package lasts 30 days", "12 ml a day"), the days for delivery, what is there now (adding
  only), the shop's link, notes, and a barcode typed in, checked by its check digit and looked up as the phone's scan
  does (the household's own item, the catalog, Open Pet Food Facts, UPCitemdb); a new item's **"Fill from photos"**
  (up to 3 photos of the package, read by AI: name, brand, kind, size, energy; what the barcode found stays first);
  "Stop buying" and deleting after asking. The API has no price yet (the spec's data model names one), so the form
  has none.
- **Settings**: the profile (the name others see; this browser's language; the phone's time zone, read only: the web
  never sends the language or the time zone), the theme (the system's, light or dark, kept in this browser), the
  group (its name and time zone, the people and their roles, invites with a code and a link to copy, revoking them;
  for owners), the person's groups (switch, create, join with a code, leave, delete an empty one of one's own), the
  group's plan and this month's AI photos and whether AI is set up (read only), where reminders come (the phone app),
  Help ("Getting to know the app" again), "Download my data" (the ZIP the server names, with the bytes so far and the
  server's limit of 5 an hour) and
  **"Delete account…"**: a page that shows what happens to each group (handed over to whom, kept, or deleted with its
  pets), what goes and what stays, then asks for a tick and the password again; afterwards the browser is signed out
  and the sign-in page says the account was deleted. A link to the site's page about deleting stays.
- **Joining a group** at `/app/join#ABCD-2345`: an invite's link carries the code after "#", which a browser never
  sends to a server, so no server's log holds it.
- **Groups**: the household on screen is picked in the sidebar or in Settings; helpers see everything and only mark
  things (fed, "Done", a visit took place, bought, a stock count); the forms (and AI) are not for them.
- **Live updates**: what someone else in the household changes (on a phone or in another tab) shows at once; the
  sidebar says "Live", "Connecting…" or "Reconnecting…" (nothing while they are off).

## Run it

```sh
npm install
npm run dev        # http://localhost:5182/app/ against the public server
npm run dev:mock   # the demo: no account, no server
```

The dev server sends `/api/…` and `/health` to the public server, so you sign in with a real account. Another server:
`CB_API=http://localhost:5000 npm run dev`. Node 22.15 or newer.

**The demo** (`npm run dev:mock`, like the admin's) is the app with the tests' pretend server and sign-in and a
made-up household: a cat and a dog with plans (due, overdue, paused), a history of vaccinations, treatments, an
antibody test and check-ups, a passport with its pages, documents with image pages and a PDF, feeding schedules,
supplies in every state of the list with their purchases and counts, weighings and a vet's weights, visits, the
household's people (a member and a sitter who helps) and an open invite, a second household (on Premium) where you
only help, and a third one to join with the code `NBRS-2345`. "Find" knows the barcodes 5901234123457 (Open Pet Food
Facts) and 4006381333931 (UPCitemdb). The cat has a scan ready to check (records, a weighing, microchips and the
passport, with every kind of the AI's doubts) and a note that failed; a new scan or note is "read" in 3.5 seconds;
a chip's photo holds two numbers, so the pet form asks which; package photos read as a bag of dry food. The live
updates connect to a pretend hub that hears nothing (nobody else changes the demo). "Delete account…" shows the
groups' fates and, with any password but "wrong", signs out as deleted. Every screen works; changes last until the tab is reloaded; files you drop
stay on your computer, and "Download my data" saves a small ZIP. The address takes switches: `?mockLang=ru` (the
data in Russian; else the language picked in this browser, else the browser's), `?mockUser=none` (start signed out:
any e-mail and password sign in, the password "wrong" doesn't), `?mockLatency=0` (answers at once, not after 300 ms),
`?mockWorld=new` (a new account with an empty household: Home opens the onboarding by itself the first time in this
browser), `?mockWorld=pets` (the pets with nothing set up: the first steps) and `?mockWorld=done` (the day done: "All
done for today").
The sidebar says "Demo" all the while. A normal build leaves the demo out.

| Command | What it does |
|---|---|
| `npm run dev` | the app with live reload on port 5182 |
| `npm run dev:mock` | the demo: made-up data, the pretend sign-in and server (`src/mock/`) |
| `npm run build` | `dist/`, the files nginx serves under `/app/` |
| `npm run preview` | `dist/` served locally, to look at the build |
| `npm run typecheck` | TypeScript over the app, its tests and `vite.config.ts` |
| `npm test` | the tests (Vitest, jsdom), on a pretend server: no network |
| `npm run generate-api` | `src/api/schema.d.ts` from `../contracts/openapi.json`; `-- --check` only says whether it is current |
| `npm run tokens` | `src/styles/tokens.css` from `../design/tokens.json` (the landing's generator), then `src/styles/theme.css` from it (`tool/gen-theme.mjs`); `check-tokens` checks both |

After the API changes (the server writes `contracts/openapi.json`), run `npm run generate-api`: the new types show
what the web app has to follow, as type errors. CI fails while the generated file is stale, like the app's Dart client.

The theme picked in Settings needs the tokens' colours under `data-theme` on `<html>` too: `tokens.css` has the dark
ones only under the system's `prefers-color-scheme`. `tool/gen-theme.mjs` writes them from `tokens.css` into
`theme.css` (Node only: CI checks the tokens before `npm ci`), and `index.html` sets `data-theme` before the first
paint, so a dark pick never flashes white.

The generator, `tool/generate-api.mjs`, runs openapi-typescript. That needs TypeScript's JavaScript API, which
TypeScript 7 (the compiler of this app) no longer has, so openapi-typescript gets TypeScript 6 as a library
(`@typescript/typescript6`); `overrides` in `package.json` tells npm that openapi-typescript's wish for TypeScript 5
is taken care of.

## How it is built and served

Vite builds the app for `/app/` (`base` in `vite.config.ts`). On the server it is part of the **web** container
(`deploy/web.Dockerfile`, a build stage next to the landing's and the admin's), and nginx serves it
(`deploy/nginx.conf`): one page for every address under `/app/`, checked for a newer version on every visit; the
assets have hashed names and are cached for a year; nothing is indexed. CI (`.github/workflows/ci.yml`, "Web (React)")
checks the tokens and the API types, then typechecks, tests and builds; after CI passes on `main` the server deploys.

## What's where

```text
src/
  main.tsx            the start: styles, the sign-in and network (services.ts: real, or the demo's), the router
  App.tsx             the providers: React Query, the language, toasts, the session
  routes.tsx          the addresses
  session.tsx         signed in or not; GET /me first; signing out on a 401
  household/          the household on screen (X-Household), what the role may do, today's date in its zone
  live/               live updates: when to connect (live.ts), the SignalR client (signalr.ts), which pages each
                      topic touches (topics.ts), the provider and the sidebar's status (LiveProvider.tsx)
  api/                the client (openapi-fetch + schema.d.ts), errors in words, query keys, the queries,
                      uploads and file links, whether the server answers
  auth/               the sign-in: what the app needs of it (auth.ts) and Firebase (firebase.ts)
  i18n/               en.ts and ru.ts (every text), plurals, dates and times
  lib/                rules repeated from the server: dates, care, weights and the chart's maths, feeding,
                      supplies (units, groups, the barcode's check digit), invite codes, documents, the passport,
                      microchip numbers, typed numbers, labels
  components/         the frame (sidebar, menu), fields, dialogs, toasts, action cards, the photo, the offline strip,
                      the drop zone and file tiles, the page viewer, the weight chart, the leave guard
  pages/              Home (home/), getting to know the app (welcome/), Today (today/), Pets (pets/), the pet's
                      Health (health/: plans, records, the bulk entry), Passport (passport/), Documents (documents/),
                      Feeding (feeding/), Weight (weight/), Visits (visits/), Supplies (supplies/), Settings, deleting
                      the account and joining a group (settings/), AI scans and notes with their review (scans/),
                      sign-in and the rest
  theme.ts            the theme picked in this browser
  styles/             tokens.css and theme.css (generated), fonts.css, app.css
  test/               the pretend server (with the server's ready-made plans and AI, its problems typed as
                      ASP.NET's), sign-in and hub, the AI drafts' builders, a slow HEIC decoder, the render helper
  mock/               the demo: its world in English and Russian, its pictures, its services
tool/generate-api.mjs the API types
tool/gen-theme.mjs    styles/theme.css from styles/tokens.css
```

### How the app talks to the server

- Every request carries `Authorization: Bearer <Firebase ID token>`, `X-Household: <the household on screen>` and
  `X-Client: <this tab's id>` (the live updates' origin). A page, dialog or form keeps the client of the household it
  was opened in, so its changes can't land in another one.
- React Query keeps what pages read, per household; it reads again when the window comes back to the front, and Today
  every 30 seconds while live updates are off.
- **Live updates** (`src/live/`, the phone's LiveUpdates): a browser's WebSocket can't send the sign-in token in a
  header, so each attempt first gets a one-time ticket (`POST /live/tickets`, the person's own: no `X-Household`) and
  connects to `/hubs/household?household=<id>&access_token=<ticket>` (SignalR, WebSockets only). A change names its
  topics; the pages that show them read again (the phone's map, in `topics.ts`), in one go per 300 ms; a change this
  tab made comes back with its `X-Client` and is skipped. Connected again after a time it heard nothing (a failure, a
  drop, a refusal, the tab hidden for long), the household's pages read again (the server keeps no history); not on
  the first connection, as the pages have just been read. Another household on screen: a new connection. A failure
  or a drop: tries again after 1, 2, 5, 10 and 30 seconds, then every 30, each with a fresh ticket. The tab hidden for
  30 seconds: closed until it is shown. The server refusing the household: no tries until another one is on screen or
  the tab is shown again.
- **AI** (`src/pages/scans/`): the photos go up first (`POST /files`), then `POST /ai-imports` (answered 202) with a
  request id kept for the same photos or text, and `retryOf` when a failed scan is read again (the server throws the
  old one away). The scan's page asks every 2 seconds while it is read. "Save selected" is `POST
  /ai-imports/{id}/apply` with what is ticked as edited, `keepPhotos`, and a plan per record; the server's field
  errors (`records[1].record.product`) go back on their entries. A lost answer: the scan is asked for before the next
  try, and one saved meanwhile shows as saved. The review opens only from the scan as read since its page opened, and
  a scan saved or thrown away here is written into its page's cache at once (the live updates skip the tab's own
  changes). The month's photos (409 ai-limit), the day's notes (429 text-limit), the pace (any other 429, with
  Retry-After) and AI not set up (any other 409: ASP.NET fills in RFC 9110's type, which says nothing more) are said
  in words; not set up, whether AI is set up is read again, and its buttons go. A chip's number and a package come
  from `POST /pets/identifiers/scan` and `POST /products/scan`, with 1–3 photos and no draft to keep; one card reads at
  a time.
- **Deleting the account**: `GET /me/deletion` (the groups' fates and a fingerprint of them, the person's own), the
  password again (Firebase's reauthentication, so the token is fresh), then `DELETE /me?plan=<fingerprint>` with the
  fates she ticked "I understand" for. Another picture of them (409, a live update, a reload): "Something changed",
  the tick goes, and she ticks again for what she sees. 403 recent sign-in: the password is asked for again. Signed
  out because the account is gone (here, on a phone, or by a deletion whose answer got lost), the browser forgets the
  household it remembered for it.
- `403 not-a-household-member`: the households are read again and the app moves to the first one, saying why.
  `403 role-forbidden`: the role is read again (an owner may have changed it). `401 account-deleted`: sign out, and the
  sign-in page says the account was deleted.
- No answer: a strip says the server can't be reached; it asks `/health` every 20 seconds, and when the server is
  back every page loads again. A reload that fails otherwise keeps what is on screen under the reason; something
  deleted (404) is said instead of an old copy.
- Additions carry a request id (plans, records, schedules, weighings, visits, "Done", items, purchases and counts),
  kept across retries: a retry after a lost answer adds nothing twice, and a correction typed between the lost answer
  and the retry follows it (a PUT; a purchase or a count, which the API can't change, is taken back and entered
  again). The bulk entry has one per row. A new document has none in the API yet: a retry
  looks for the document the last try made (the one holding any of its files) and brings it up to the dialog.
- `?lang=ru` in the address (the landing's "Web version" link from its Russian pages) is the language when this
  browser has none picked yet, and is kept as picked.
- "Download my data" comes as a stream (the server doesn't know its size beforehand) and is saved under the name in
  its Content-Disposition; a 429's Retry-After says how many minutes to wait.
- Files go up one by one (`POST /files`), then to their place (a record, a document's pages), never as a list that
  would replace what is there. Download links live 15 minutes and change in every answer: a file keeps the link it
  was first shown with while that lives (by its id), a picture whose link died asks for a fresh one, and a PDF opens
  in a new tab with a link that still lives.
- Leaving a form with typed input asks first ("Leave without saving?"), dialogs too, and another household chosen on
  the page itself (Settings); while a form saves, leaving (a link, Back, another household) waits for it, and what it
  saved opens in the household it was saved to. A move while a dialog saves, or while files upload, waits and then
  goes on (or asks, when the save or the upload failed); the tab's closing asks meanwhile.

### Texts

Every text is in `src/i18n/en.ts`, with the phone app's words where it has them, and its Russian twin in `ru.ts`
(the type makes a missing key an error, and a test checks every key and plural form). The language: the one picked in
the sidebar on this browser (or brought by the landing's link, `?lang=`), else the profile's (`GET /me`), else the
browser's.

### Buttons

Calls to action are buttons you want to press, as on the phone (`docs/mvp-spec.md`, "Главная, знакомство, кнопки"):
the main action of a page or section is a primary button (`button--primary`), the others outlined
(`button--secondary`), or action cards (`components/ActionCard.tsx`: an icon in a mint circle, a title, a line of why,
a chevron; the whole card is the link) where several things can be started: empty pages, Home's quick actions, the
onboarding. Text-only buttons (`button--ghost`) are left for escapes and answers: "Cancel", "Skip", "Close", deleting
and removing one thing; an icon alone only in a toolbar, with its name for screen readers.
