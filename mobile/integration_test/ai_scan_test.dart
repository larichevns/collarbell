// End-to-end test of milestone M3 against a running local API with real AI
// (dev sign-in): a cat has a rabies plan; a passport page with a rabies
// vaccination (drawn at runtime instead of the document scanner) is
// scanned; the review shows the vaccination as a "Done" of the plan;
// saving puts it in the history and moves the plan to the vaccine's "valid
// until". It also looks at the AI screen and its connection test, and
// photographs the review in Russian with the dark theme.
//
//   cd backend && dotnet run --project src/Collarbell.AppHost
//   cd mobile && flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/ai_scan_test.dart -d <simulator> \
//     --dart-define=CB_API_BASE_URL=http://localhost:5080
//
// The AppHost needs the Gemini key in its user secrets (see AppHost.cs).
// Real AI takes 10–60 seconds, more when a model is busy and the next one
// takes over: the test waits up to three minutes. Screenshots are written
// to build/screenshots/ (8x-*.png).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:collarbell/app/app.dart';
import 'package:collarbell/app/app_settings.dart';
import 'package:collarbell/features/ai/ai_screen.dart';
import 'package:collarbell/features/ai/scan_screen.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/care_repository.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/care/widgets/record_row.dart';
import 'package:collarbell/features/files/media_picker.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/more/more_screen.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/features/pets/pets_screen.dart';
import 'package:collarbell/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collarbell/features/notifications/push_platform.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'helpers.dart';

/// The test's own developer account: its household holds only test pets.
const testEmail = 'e2e-scan@collarbell.local';

/// How long real AI may take, a busy model and its fallbacks included.
const aiTimeout = Duration(minutes: 3);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scans a passport page, checks the draft and saves it as the '
      "rabies plan's Done", (tester) async {
    // Start signed out, in English with the light theme.
    final prefs = await SharedPreferences.getInstance();
    final previousEmail = prefs.getString(DevAuthRepository.lastEmailKey);
    final previousLanguage = prefs.getString(AppSettingsNotifier.languageKey);
    final previousTheme = prefs.getString(AppSettingsNotifier.themeModeKey);
    await DevAuthRepository(prefs).signOut();
    await skipOnboarding(prefs, testEmail);
    await prefs.setString(AppSettingsNotifier.languageKey, 'en');
    await prefs.setString(AppSettingsNotifier.themeModeKey, 'light');

    await app.runCollarbell(
      overrides: [
        mediaPickerProvider.overrideWithValue(RabiesPagePicker()),
        pushPlatformProvider.overrideWithValue(const DisabledPushPlatform()),
      ],
    );

    try {
      final continueAsDeveloper = find.text('Continue as developer');
      await pumpUntil(tester, continueAsDeveloper);
      await tester.enterText(field('Developer email'), testEmail);
      await hideKeyboard(tester);
      await tester.tap(continueAsDeveloper);
      await pumpUntil(tester, find.text('Today'));
      await deleteAllPets(tester);

      // Barsik with a rabies plan due in a month, made through the app's
      // own repositories.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CollarbellApp)),
      );
      final pet = await container
          .read(petsRepositoryProvider)
          .createPet(const PetInput(name: 'Barsik', species: PetSpecies.cat));
      final now = DateTime.now();
      await container
          .read(careRepositoryProvider)
          .createPlan(
            pet.id,
            CarePlanInput(
              kind: CareKind.vaccination,
              title: 'Rabies',
              interval: const CareInterval(1, IntervalUnit.year),
              nextDueOn: DateTime(now.year, now.month + 1, now.day),
              targets: const [VaccineTarget.rabies],
              presetCode: 'cat-rabies',
            ),
            requestId: const Uuid().v4(),
          );

      // His Passport tab offers the scan: the server has AI.
      await tester.tap(petsTab());
      final barsik = find.widgetWithText(PetRow, 'Barsik');
      await pumpUntil(tester, barsik);
      await tester.tap(barsik);
      await pumpUntil(tester, find.text('Overview'));
      await tester.tap(find.text('Passport'));
      await pumpUntil(tester, find.text('Scan passport pages'));
      await settle(tester);
      await binding.takeScreenshot('80-passport-scan-card');

      await tester.tap(find.text('Scan pages'));
      await pumpUntil(tester, find.text('Scan with the camera'));
      await settle(tester);
      await binding.takeScreenshot('81-scan-start');

      // The "scanner" returns the drawn page; it uploads and AI reads it.
      await tester.tap(find.text('Scan with the camera'));
      await pumpUntil(tester, find.text('Reading the pages…'));
      await settle(tester);
      await binding.takeScreenshot('82-scan-reading');

      final review = find.text('Check the scan');
      final failed = find.text("Couldn't be read");
      await pumpUntil(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Check the scan' ||
                  widget.data == "Couldn't be read"),
        ),
        timeout: aiTimeout,
      );
      if (failed.evaluate().isNotEmpty) {
        await binding.takeScreenshot('83-scan-failed');
        fail(
          'The scan failed: ${[for (final e in find.byType(Text).evaluate()) (e.widget as Text).data].join(' | ')}',
        );
      }
      expect(review, findsOneWidget);
      await settle(tester);
      await binding.takeScreenshot('83-scan-review');

      // The rabies vaccination, as a "Done" of the rabies plan.
      final linked = find.text('Mark as done in plan “Rabies”');
      await pumpUntil(tester, linked);
      await tester.ensureVisible(linked);
      await settle(tester);
      await binding.takeScreenshot('84-scan-review-plan');
      expect(find.textContaining('Nobivac'), findsWidgets);

      // The same review in Russian with the dark theme.
      final settings = container.read(appSettingsProvider.notifier);
      await settings.setLanguage(LanguagePreference.ru);
      await settings.setThemeMode(ThemeMode.dark);
      await pumpUntil(tester, find.text('Проверка скана'));
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 3000),
      );
      await settle(tester);
      await binding.takeScreenshot('85-scan-review-ru-dark');
      await settings.setLanguage(LanguagePreference.en);
      await settings.setThemeMode(ThemeMode.light);
      await pumpUntil(tester, review);
      await settle(tester);

      // Save what is ticked.
      final save = find.textContaining(RegExp(r'^Save \d+ selected$'));
      await tester.tap(save);
      await pumpUntil(tester, find.byType(PassportTab));
      await pumpUntil(tester, find.textContaining('Saved 1 record'));
      // The scan screen has closed once its page has slid away.
      await settle(tester);
      expect(find.byType(ScanScreen), findsNothing);
      expect(find.textContaining('1 plan updated'), findsOneWidget);
      await settle(tester);
      await binding.takeScreenshot('86-passport-after-scan');

      // The Health tab: the record in the history, and the plan moved to
      // the day the vaccine stops protecting.
      await tester.tap(find.text('Health'));
      await pumpUntil(tester, find.byType(HealthTab));
      await pumpUntil(tester, find.textContaining('Mar 11, 2028'));
      final record = find.byType(RecordRow);
      await scrollTo(tester, record, scrollable: scrollableIn(HealthTab));
      expect(
        find.descendant(of: record, matching: find.textContaining('Nobivac')),
        findsOneWidget,
      );
      await settle(tester);
      await binding.takeScreenshot('87-health-after-scan');

      // More → AI: connected, the models, this month's use, a live test.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('More'),
        ),
      );
      final aiRow = find.text('Reading photos with AI');
      await pumpUntil(tester, find.text('Signed in as'));
      await scrollTo(tester, aiRow, scrollable: scrollableIn(MoreScreen));
      await tester.tap(aiRow);
      await pumpUntil(tester, find.text('gemini-3.8-flash'));
      await settle(tester);
      await binding.takeScreenshot('88-ai-screen');
      final test = find.text('Test connection');
      await scrollTo(tester, test, scrollable: scrollableIn(AiScreen));
      await tester.tap(test);
      await pumpUntil(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              ((widget.data ?? '').startsWith('It works') ||
                  (widget.data ?? '').startsWith("It doesn't work")),
        ),
        timeout: aiTimeout,
      );
      await settle(tester);
      await binding.takeScreenshot('89-ai-test');
      expect(find.textContaining('It works'), findsOneWidget);
    } finally {
      // Leave no test pets behind even when a step failed, and leave the
      // device as it was: signed out, with the previous email and settings.
      if (find.byType(CollarbellApp).evaluate().isNotEmpty) {
        await deleteAllPets(tester);
      }
      await DevAuthRepository(prefs).signOut();
      Future<void> restore(String key, String? value) async {
        if (value == null) {
          await prefs.remove(key);
        } else {
          await prefs.setString(key, value);
        }
      }

      await restore(DevAuthRepository.lastEmailKey, previousEmail);
      await restore(AppSettingsNotifier.languageKey, previousLanguage);
      await restore(AppSettingsNotifier.themeModeKey, previousTheme);
    }
  });
}

/// Stands in for the document scanner and the photo library: returns a
/// page of an EU pet passport with a rabies vaccination, drawn at runtime.
class RabiesPagePicker implements MediaPicker {
  @override
  Future<PickedMedia?> takePhoto() => drawRabiesPage();

  @override
  Future<PickedMedia?> pickPhoto() => drawPetPhoto();

  @override
  Future<List<PickedMedia>> pickPhotos({int? limit}) async => [
    await drawRabiesPage(),
  ];

  @override
  Future<PickedMedia?> pickPdf() async => null;

  @override
  Future<List<PickedMedia>?> scanPages({required int maxPages}) async => [
    await drawRabiesPage(),
  ];

  @override
  Future<List<PickedMedia>> prepareScans(List<PickedMedia> pages) async =>
      pages;

  @override
  Future<void> deletePicked(List<PickedMedia> media) async {
    for (final item in media) {
      final file = File(item.path);
      if (file.existsSync()) await file.delete();
    }
  }
}

/// Section V of an EU pet passport with one rabies vaccination: Nobivac
/// Rabies by MSD, batch A123B45, given on 12/03/2025 and valid until
/// 11/03/2028 (day first, as in EU passports).
Future<PickedMedia> drawRabiesPage() async {
  const width = 1240.0;
  const height = 1754.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xFFF7F3E8),
  );
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, 120),
    Paint()..color = const Color(0xFF1F3A93),
  );

  void text(
    String value,
    double x,
    double y, {
    double size = 40,
    Color color = const Color(0xFF151515),
    FontWeight weight = FontWeight.w400,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(fontSize: size, fontWeight: weight),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(value);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width - x - 60));
    canvas.drawParagraph(paragraph, Offset(x, y));
  }

  void rule(double y) => canvas.drawRect(
    Rect.fromLTWH(60, y, width - 120, 3),
    Paint()..color = const Color(0xFF555555),
  );

  text(
    'EUROPEAN UNION · PET PASSPORT',
    60,
    38,
    size: 40,
    color: const Color(0xFFFFFFFF),
  );
  text(
    'V. VACCINATION AGAINST RABIES',
    60,
    180,
    size: 56,
    weight: FontWeight.w700,
  );
  rule(280);
  const rows = [
    ('Manufacturer and name of vaccine', 'Nobivac Rabies, MSD'),
    ('Batch number', 'A123B45'),
    ('Date of vaccination', '12/03/2025'),
    ('Valid from', '12/03/2025'),
    ('Valid until', '11/03/2028'),
    ('Authorised veterinarian', 'Dr. Anna Weber, Berlin'),
  ];
  var y = 320.0;
  for (final (label, value) in rows) {
    text(label, 60, y, size: 34, color: const Color(0xFF555555));
    text(value, 60, y + 48, size: 52, weight: FontWeight.w700);
    y += 160;
    rule(y - 24);
  }
  return savePng(recorder, width, height, 'rabies-page.png');
}
