import 'dart:convert';
import 'dart:typed_data';

import 'package:collarbell/app/app.dart';
import 'package:collarbell/app/app_config.dart';
import 'package:collarbell/app/live_updates.dart';
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_providers.dart';
import 'package:collarbell/data/api/offline_cache.dart';
import 'package:collarbell/features/account/account_repository.dart';
import 'package:collarbell/features/account/export_files.dart';
import 'package:collarbell/features/ai/ai_repository.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/billing/billing_repository.dart';
import 'package:collarbell/features/care/care_repository.dart';
import 'package:collarbell/features/documents/documents_repository.dart';
import 'package:collarbell/features/feeding/feeding_repository.dart';
import 'package:collarbell/features/files/files_repository.dart';
import 'package:collarbell/features/files/media_picker.dart';
import 'package:collarbell/features/files/widgets/stored_file_image.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/household/household_repository.dart';
import 'package:collarbell/features/me/me_repository.dart';
import 'package:collarbell/features/me/profile_sync.dart';
import 'package:collarbell/features/notifications/notifications_repository.dart';
import 'package:collarbell/features/notifications/push_platform.dart';
import 'package:collarbell/features/onboarding/onboarding.dart';
import 'package:collarbell/features/passport/passport_repository.dart';
import 'package:collarbell/features/pets/chip_reader.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/features/supplies/barcode_reader.dart';
import 'package:collarbell/features/supplies/supplies_repository.dart';
import 'package:collarbell/features/today/today_repository.dart';
import 'package:collarbell/features/visits/visits_repository.dart';
import 'package:collarbell/features/weight/weight_repository.dart';
import 'package:collarbell/l10n/app_localizations.dart';
import 'package:collarbell/shared/share_text.dart';
import 'package:collarbell/shared/widgets/cb_date_field.dart';
import 'package:collarbell/theme/collarbell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// A 1×1 transparent PNG.
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x7A, 0x5E, 0xAB, 0x3F, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Stored files show a local pixel: cached_network_image needs a disk cache
/// (a plugin) that widget tests don't have.
final storedImageTestOverride = storedImageProvider.overrideWithValue(
  (url, cacheKey) => MemoryImage(_pixel),
);

/// Replaces every repository and the media picker with fakes, so no test
/// talks to a server or opens the camera. Pass the fakes a test inspects.
List<Override> fakeRepositories({
  FakePetsRepository? pets,
  FakePassportRepository? passport,
  FakeDocumentsRepository? documents,
  FakeFilesRepository? files,
  FakeMediaPicker? picker,
  FakeCareRepository? care,
  FakeTodayRepository? today,
  FakeAiRepository? ai,
  FakeFeedingRepository? feeding,
  FakeVisitsRepository? visits,
  FakeNotificationsRepository? notifications,
  FakePushPlatform? push,
  FakeSuppliesRepository? supplies,
  FakeBarcodeReader? barcodes,
  FakeChipReader? chips,
  FakeHouseholdRepository? household,
  FakeShare? share,
  FakeBillingRepository? billing,
  FakeAccountRepository? account,
  FakeExportFiles? exportFiles,
  FakeWeightRepository? weight,
}) => [
  petsRepositoryProvider.overrideWithValue(pets ?? FakePetsRepository()),
  aiRepositoryProvider.overrideWithValue(ai ?? FakeAiRepository()),
  careRepositoryProvider.overrideWithValue(care ?? FakeCareRepository()),
  todayRepositoryProvider.overrideWithValue(today ?? FakeTodayRepository()),
  passportRepositoryProvider.overrideWithValue(
    passport ?? FakePassportRepository(),
  ),
  documentsRepositoryProvider.overrideWithValue(
    documents ?? FakeDocumentsRepository(),
  ),
  filesRepositoryProvider.overrideWithValue(files ?? FakeFilesRepository()),
  mediaPickerProvider.overrideWithValue(picker ?? FakeMediaPicker()),
  feedingRepositoryProvider.overrideWithValue(
    feeding ?? FakeFeedingRepository(),
  ),
  visitsRepositoryProvider.overrideWithValue(visits ?? FakeVisitsRepository()),
  notificationsRepositoryProvider.overrideWithValue(
    notifications ?? FakeNotificationsRepository(),
  ),
  suppliesRepositoryProvider.overrideWithValue(
    supplies ?? FakeSuppliesRepository(),
  ),
  barcodeReaderProvider.overrideWithValue(barcodes ?? FakeBarcodeReader()),
  chipReaderProvider.overrideWithValue(chips ?? FakeChipReader()),
  householdRepositoryProvider.overrideWithValue(
    household ?? FakeHouseholdRepository(),
  ),
  shareTextProvider.overrideWithValue((share ?? FakeShare()).share),
  billingRepositoryProvider.overrideWithValue(
    billing ?? FakeBillingRepository(),
  ),
  accountRepositoryProvider.overrideWithValue(
    account ?? FakeAccountRepository(),
  ),
  exportFilesProvider.overrideWithValue(exportFiles ?? FakeExportFiles()),
  weightRepositoryProvider.overrideWithValue(weight ?? FakeWeightRepository()),
  // No pushes unless a test asks: the phone acts like an iPhone for now.
  pushPlatformProvider.overrideWithValue(
    push ?? FakePushPlatform(supported: false),
  ),
];

/// Pumps [screen] with the Collarbell light theme (no font downloads), the
/// app's localizations and the given provider overrides, signed in as a
/// developer in a household where the user has [role] (saved on the phone,
/// as after an earlier start).
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  HouseholdRole role = HouseholdRole.owner,
}) async {
  SharedPreferences.setMockInitialValues({
    DevAuthRepository.uidKey: testUid,
    DevAuthRepository.emailKey: 'dev@collarbell.local',
    CurrentHouseholdNotifier.keyFor(testUid): jsonEncode(
      CurrentHousehold(
        id: FakeMeRepository.homeId,
        name: 'Home',
        role: role,
      ).toJson(),
    ),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storedImageTestOverride,
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'http://localhost:5080',
            authMode: AuthMode.dev,
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      retry: noAutomaticRetry,
      child: MaterialApp(
        theme: CollarbellTheme.light(fonts: plainFontResolver),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The developer account `pumpApp` signs in with.
const testUid = 'dev-0000000000000001';

/// Pumps the whole app, signed in as a developer, and opens [location]
/// (e.g. `/pets/p1`) with the app's own router. [overrides] usually replace
/// the repositories with fakes. [me] lists the user's households (one, as
/// its owner, by default); [household] is the one the phone saved as shown
/// last time, else the app starts with the server's choice. [offlineCopies]
/// holds the answers kept for offline use. [live] plays the server's live
/// updates; by default every connection opens and hears nothing. With
/// [authMode] firebase the screens act as with Firebase (a test overrides
/// `authRepositoryProvider` then; a developer's sign-in stands in for it).
/// The account has had its onboarding already, as after an earlier start,
/// unless [onboardingSeen] is false: Home then opens it by itself when the
/// group has no pets.
Future<void> pumpApp(
  WidgetTester tester, {
  required String location,
  List<Override> overrides = const [],
  String language = 'en',
  Size size = const Size(390, 844),
  FakeMeRepository? me,
  CurrentHousehold? household,
  MemoryOfflineCacheStore? offlineCopies,
  FakeLiveServer? live,
  AuthMode authMode = AuthMode.dev,
  bool onboardingSeen = true,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    DevAuthRepository.uidKey: testUid,
    DevAuthRepository.emailKey: 'dev@collarbell.local',
    'settings.language': language,
    if (household != null)
      CurrentHouseholdNotifier.keyFor(testUid): jsonEncode(household.toJson()),
    if (onboardingSeen) OnboardingTurn.keyFor(testUid): true,
  });
  final prefs = await SharedPreferences.getInstance();
  final profile = me ?? FakeMeRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Widget tests have no app storage folder (a plugin).
        offlineCacheStoreProvider.overrideWithValue(
          offlineCopies ?? MemoryOfflineCacheStore(),
        ),
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'http://localhost:5080', authMode: authMode),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        fontResolverProvider.overrideWithValue(plainFontResolver),
        // `/me` answers for the household the app names, like the server.
        meRepositoryProvider.overrideWith(
          (ref) =>
              profile..selected = () => ref.read(currentHouseholdProvider)?.id,
        ),
        deviceTimeZoneProvider.overrideWithValue(() async => 'Europe/Berlin'),
        // No test talks to a server: live updates connect to a fake.
        realtimeClientFactoryProvider.overrideWithValue(
          (live ?? FakeLiveServer()).newClient,
        ),
        storedImageTestOverride,
        ...overrides,
      ],
      retry: noAutomaticRetry,
      child: const CollarbellApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CollarbellApp)),
  );
  // The app opens on Home by itself; a `go` there would also close what
  // Home opened over itself (the onboarding).
  if (location != AppRoutes.home) {
    container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
  }
}

/// Lets the fakes answer and the routes move, without waiting for a
/// spinner that never settles (a scan being read).
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Like [tapVisible], for screens with a spinner: scrolls [finder] into
/// view and taps it, then lets the fakes answer ([pumpFrames]).
Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await pumpFrames(tester);
}

/// Scrolls [finder] into view (lists build rows beyond the screen edge, so
/// being in the tree is not enough) and taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens the date field labelled [label] and types [date] in the date
/// picker's input mode, as a user would.
Future<void> pickDate(WidgetTester tester, String label, DateTime date) async {
  await tapVisible(
    tester,
    // The field itself, not the clear button inside it.
    find
        .descendant(
          of: find.widgetWithText(CbDateField, label),
          matching: find.byType(InkWell),
        )
        .first,
  );
  await enterPickerDate(tester, date);
}

/// Types [date] into the open date picker and confirms it.
Future<void> enterPickerDate(WidgetTester tester, DateTime date) async {
  await tester.tap(find.byTooltip('Switch to input'));
  await tester.pumpAndSettle();
  final dialog = find.byType(DatePickerDialog);
  final localizations = MaterialLocalizations.of(tester.element(dialog));
  await tester.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)),
    localizations.formatCompactDate(date),
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// The app's router, to go somewhere the way a link or the app would.
GoRouter appRouter(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(CollarbellApp)),
).read(routerProvider);

/// The app's providers, to look at or change what the app holds.
ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CollarbellApp)));

/// Types [time] into the open time picker (its text mode) and confirms it.
/// The tests run with a 12-hour clock, as in English by default.
Future<void> enterPickerTime(WidgetTester tester, TimeOfDay time) async {
  await tester.tap(find.byTooltip('Switch to text input mode'));
  await tester.pumpAndSettle();
  final dialog = find.byType(TimePickerDialog);
  final fields = find.descendant(of: dialog, matching: find.byType(TextField));
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  await tester.enterText(fields.at(0), '$hour');
  await tester.enterText(fields.at(1), time.minute.toString().padLeft(2, '0'));
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.text(time.period == DayPeriod.am ? 'AM' : 'PM'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
