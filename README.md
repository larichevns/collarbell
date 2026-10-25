# Collarbell

A care tracker for cat and dog households: feeding reminders, vaccinations and parasite treatments, a digital copy of the pet passport, and food supplies that don't run out.

- **How to read the code (start here)** — [docs/code-guide.md](docs/code-guide.md)
- Product research — [docs/product-research.md](docs/product-research.md)
- MVP spec and milestones — [docs/mvp-spec.md](docs/mvp-spec.md)
- System design — [docs/system-design.md](docs/system-design.md)
- Name check — [docs/naming.md](docs/naming.md)
- Design system tokens live in [design/tokens.json](design/tokens.json)
- **The server** — <https://collarbell.example.com>; how it runs and deploys: [deploy/README.md](deploy/README.md)

## Repository

```text
backend/      .NET 10: Aspire AppHost, API (modular monolith), tests
mobile/       Flutter app (iOS, Android)
landing/      the public site (Astro): home, privacy, terms, account deletion, support; EN and RU
deploy/       the server: docker compose, nginx routes, deploy with rollback, backups
contracts/    openapi.json, written by the backend build; clients are generated from it
design/       design tokens (source for the Flutter theme)
tools/        generators (design tokens → Dart)
docs/         research, spec, system design
```

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| .NET SDK | 10.0.1xx (see `backend/global.json`) | `brew install dotnet` |
| Aspire CLI | 13.6 | `dotnet tool install -g Aspire.Cli` |
| Docker | running | Docker Desktop |
| Flutter | 3.38.9 stable | `brew install --cask flutter` |
| Xcode / Android SDK | for running the app | — |
| Firebase CLI, FlutterFire CLI | for real sign-in | `npm i -g firebase-tools`, `dart pub global activate flutterfire_cli` |

## Run locally

**Backend** — Postgres and SeaweedFS (file storage with an S3 API) in Docker, plus the API, with the Aspire dashboard:

```bash
cd backend
dotnet run --project src/Collarbell.AppHost
```

- API: <http://localhost:5080> (OpenAPI at `/openapi/v1.json`, Scalar UI at `/scalar/v1`).
- In Development the database is migrated and the storage bucket created on start.
- Files: S3 API on <http://localhost:8333>. The API hands out 15-minute signed links to it, which the iOS simulator can open as they are. A real phone needs the `phone` profile (below).
- Postgres and SeaweedFS keep their data in Docker volumes (`collarbell-postgres-data`, `collarbell-storage-data`) between runs.
- Without Firebase you sign in as a dev user with headers:

  ```bash
  curl -H "X-Dev-User: anna" -H "X-Dev-Email: anna@example.com" http://localhost:5080/api/v1/me
  ```

  The first call creates the user and a household. Dev users exist only in Development and Testing (`Auth:DevUsers:Enabled`).

**Mobile** — see [mobile/README.md](mobile/README.md). In short:

```bash
cd mobile
flutter run --dart-define=CB_API_BASE_URL=http://localhost:5080
```

In debug builds the app uses dev sign-in by default; see [Firebase sign-in](#firebase-sign-in) to use real accounts.

**On your Android phone** — with the phone on a USB cable and USB debugging on:

```bash
sh mobile/tool/install_phone.sh
```

- The script builds a release app that talks to the server (<https://collarbell.example.com>, [deploy/README.md](deploy/README.md)) and installs it over USB. The phone signs in with Firebase (e-mail and password).
- Xiaomi phones also need "Install via USB" in Developer options, and every install asks for a tap on the phone.
- To try a change on the phone before deploying it, run the API on the Mac in phone mode and pass the Mac's address to the script:

  ```bash
  cd backend
  dotnet run --project src/Collarbell.AppHost --launch-profile phone
  # in another terminal:
  sh mobile/tool/install_phone.sh http://<the Mac's Wi-Fi address>:5080
  ```

  The `phone` profile makes the API (port 5080) and the file links (port 8333) listen on every address of the Mac, and signs links for its Wi-Fi address. Dev sign-in is off there, since anyone on the network could use it.

## Firebase sign-in

Firebase project **`collarbell-3e2b9`** (free Spark plan), sign-in with **Email/Password**.

- The API accepts ID tokens from this project only: `Firebase:ProjectId` in `backend/src/Collarbell.Api/appsettings.json`.
- The app's Firebase config is committed: `mobile/lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `mobile/firebase.json`. These are project identifiers, not secrets: they ship inside every app build anyway, and Firebase documents them as safe to commit. Data is protected by sign-in on our API.
- Gemini keys never go into this Google Cloud project. They live in a separate project ([mvp-spec](docs/mvp-spec.md), AI provider decision), so the public Firebase keys can't be used to call Gemini.
- Debug builds still default to dev sign-in. To sign in with Firebase:

  ```bash
  cd mobile
  flutter run --dart-define=CB_API_BASE_URL=http://localhost:5080 --dart-define=CB_AUTH_MODE=firebase
  ```

  Release builds always use Firebase.

To re-run `flutterfire configure`, for example after adding a platform, run it under Homebrew Ruby with the gems of CocoaPods. FlutterFire edits the Xcode project with the `xcodeproj` gem, which the system Ruby lacks:

```bash
cd mobile
PATH="/opt/homebrew/opt/ruby/bin:$PATH" GEM_HOME="$(brew --prefix cocoapods)/libexec" \
  ~/.pub-cache/bin/flutterfire configure --project collarbell-3e2b9 --platforms ios,android --yes
```

## Push notifications

Reminders (feeding, vaccinations and treatments, visits) go out through Firebase Cloud Messaging, to **Android phones only for now**: an iPhone needs the paid Apple Developer Program and an APNs key in Firebase ([mvp-spec](docs/mvp-spec.md), decisions of 2026-10-02).

- The server needs the Firebase project's **service account key** (Firebase console → Project settings → Service accounts → Generate new private key). It is a secret: keep it in the AppHost's user secrets, never in the repo, then delete the downloaded file:

  ```bash
  cd backend/src/Collarbell.AppHost
  dotnet user-secrets set "Parameters:firebase-service-account" "$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' ~/Downloads/<key>.json)"
  ```

  The key must be of project `collarbell-3e2b9`; a key of another project is refused at start (pushes stay off). Without a key, reminders are still planned and listed in the app (More → Notifications), only not pushed.
- The app registers the phone after sign-in. More → Notifications shows whether pushes reach the phone, sends a test push, turns kinds of reminders on and off, and lists the coming and recent reminders with what happened to each.
- The server has its own copy of the key (`/opt/collarbell/.env`, [deploy/README.md](deploy/README.md)).
- With the API on a Mac, reminders go out only while the Mac is awake. Late ones still go out within a window (feeding 30 minutes, others a day); to keep the Mac awake while the backend runs: `caffeinate -s` in another terminal (on power).

## Supplies and product lookups

Supplies, their forecast and the "time to buy" reminders need nothing extra. Scanning a barcode looks the product up in outside databases from the server, so the server needs internet access:

- [Open Pet Food Facts](https://world.openpetfoodfacts.org) — free, no key; the app shows its data with the source (ODbL), and it isn't copied into our catalog;
- [UPCitemdb](https://www.upcitemdb.com) — the free trial API, 100 lookups a day, no key; name and brand only.

Both can be turned off in `Products` settings (`Products:OpenPetFoodFacts`, `Products:UpcItemDb`). Photos of a package are read by the same AI as passport scans: the Gemini key in the AppHost user secrets as `Parameters:gemini-api-key` ([mvp-spec](docs/mvp-spec.md), decisions of M3).

## Tests

```bash
cd backend && dotnet test   # needs Docker: tests run against Postgres and SeaweedFS containers
cd mobile && flutter test
```

End-to-end smoke test on an iOS simulator against the running local API (dev sign-in → Today → empty Pets list, with screenshots in `mobile/build/screenshots/`):

```bash
cd mobile
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/smoke_test.dart \
  -d <simulator-id> --dart-define=CB_API_BASE_URL=http://localhost:5080
```

Pets, passport pages and documents end to end: adds a pet through the form, a passport page through a stand-in camera, checks the Documents tab, then deletes the pet:

```bash
cd mobile
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/pets_passport_test.dart \
  -d <simulator-id> --dart-define=CB_API_BASE_URL=http://localhost:5080
```

Care end to end: a plan from a preset shows up on Today, "Done" moves it, a past rabies record appears in the passport section (`care_ru_test.dart` runs the same in Russian on a small phone):

```bash
cd mobile
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/care_test.dart \
  -d <simulator-id> --dart-define=CB_API_BASE_URL=http://localhost:5080
```

The same with real Firebase sign-in. It creates a throwaway account, checks that the API accepts its token, then deletes the account:

```bash
cd mobile
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/firebase_smoke_test.dart \
  -d <simulator-id> --dart-define=CB_API_BASE_URL=http://localhost:5080 --dart-define=CB_AUTH_MODE=firebase
```

CI (`.github/workflows/ci.yml`) runs the same checks. It also fails if:
- `contracts/openapi.json`, the mobile API client (`mobile/tool/generate_api.sh`) or `mobile/lib/theme/tokens.g.dart` were not regenerated and committed;
- `flutter analyze` reports issues.

## Conventions

- **API:** REST under `/api/v1`, errors as RFC 7807 problem details, enums as strings.
- **Clients** are generated from `contracts/openapi.json`. Change the API, build the backend, commit the contract.
- **Access:** all pet data belongs to a household; every query is scoped to the signed-in user's household.
- **Design:** colors, spacing and type come from the design tokens. Don't hard-code them in the app.
