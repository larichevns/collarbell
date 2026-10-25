// End-to-end test of milestone M2 against a running local API (dev sign-in):
// a cat gets a deworming plan from a preset, last done about three months
// ago, so it is due soon; Today shows it; "Done" from Today (with a photo of
// the sticker) moves it months away, so it leaves Today; a past rabies
// vaccination from the paper passport shows in the passport's section V;
// the cat is deleted again.
//
//   cd backend && dotnet run --project src/Collarbell.AppHost
//   cd mobile && flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/care_test.dart -d <simulator> \
//     --dart-define=CB_API_BASE_URL=http://localhost:5080
//
// Screenshots are written to build/screenshots/.
import 'package:collarbell/app/app.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/care_rules.dart';
import 'package:collarbell/features/care/done_screen.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/care/preset_picker_screen.dart';
import 'package:collarbell/features/care/widgets/record_row.dart';
import 'package:collarbell/features/files/media_picker.dart';
import 'package:collarbell/features/files/widgets/stored_file_image.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pets_screen.dart';
import 'package:collarbell/features/today/today_screen.dart';
import 'package:collarbell/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collarbell/features/notifications/push_platform.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// The test's own developer account: its household holds only test pets,
/// so cleaning up never touches pets added by hand.
const testEmail = 'e2e-care@collarbell.local';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plans a deworming, marks it done from Today, adds a past '
      'rabies vaccination', (tester) async {
    // Start signed out, so the test signs in to its own account.
    final prefs = await SharedPreferences.getInstance();
    final previousEmail = prefs.getString(DevAuthRepository.lastEmailKey);
    await DevAuthRepository(prefs).signOut();
    await skipOnboarding(prefs, testEmail);

    await app.runCollarbell(
      overrides: [
        mediaPickerProvider.overrideWithValue(DrawnPagePicker()),
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

      // A crashed earlier run may have left a pet behind.
      await deleteAllPets(tester);

      // Add the cat Barsik.
      await tester.tap(petsTab());
      await pumpUntil(tester, find.text('Add pet'));
      await tester.tap(find.text('Add pet'));
      await pumpUntil(tester, find.text('New pet'));
      await tester.enterText(field('Name'), 'Barsik');
      await hideKeyboard(tester);
      await tester.tap(find.text('Save'));
      // The list row, not the form's field, which says "Barsik" too.
      final barsik = find.widgetWithText(PetRow, 'Barsik');
      await pumpUntil(tester, barsik);
      await tester.tap(barsik);
      await pumpUntil(tester, find.text('Overview'));

      // His Health tab, still empty.
      await tester.tap(find.text('Health'));
      await pumpUntil(tester, find.text('Add plan'));
      await settle(tester);
      await binding.takeScreenshot('41-health-empty');

      // A deworming plan from the cat presets.
      await tester.tap(find.text('Add plan'));
      await pumpUntil(tester, find.text('Vaccinations'));
      await settle(tester);
      await binding.takeScreenshot('42-preset-picker');
      // Preset rows are keyed by their code.
      final deworming = find.byKey(const ValueKey('cat-deworm'));
      await scrollTo(
        tester,
        deworming,
        scrollable: scrollableIn(PresetPickerScreen),
      );
      await tester.tap(deworming);
      await pumpUntil(tester, find.text('New plan'));

      // Last done about three months ago: due again in five days.
      final now = DateTime.now();
      final lastDone = DateTime(now.year, now.month - 3, now.day + 5);
      final nextDue = addInterval(
        lastDone,
        const CareInterval(3, IntervalUnit.month),
      );
      await pickDate(tester, 'Last done (optional)', lastDone);
      expect(find.text(DateFormat.yMMMd('en').format(nextDue)), findsOneWidget);
      await settle(tester);
      await binding.takeScreenshot('43-plan-form');
      await tester.tap(find.text('Save'));
      await pumpUntil(tester, find.text('Due soon'));
      await settle(tester);
      await binding.takeScreenshot('44-health-due-soon');

      // Today shows it as due soon.
      await tester.tap(todayTab());
      await pumpUntil(tester, find.widgetWithText(TodayRow, 'Barsik'));
      expect(find.text('Due soon'), findsOneWidget);
      await settle(tester);
      await binding.takeScreenshot('45-today-due-soon');

      // "Done" from Today, with a photo of the sticker.
      await tester.tap(find.byTooltip('Done'));
      await pumpUntil(tester, find.byType(DoneScreen));
      await pumpUntil(tester, find.text('Mark as done'));
      final addPhotos = find.text('Add photos');
      await tester.ensureVisible(addPhotos);
      await settle(tester);
      await tester.tap(addPhotos);
      await pumpUntil(tester, find.text('Choose from library'));
      await tester.tap(find.text('Choose from library'));
      await pumpUntil(tester, find.byType(PickedMediaTile));
      await tester.ensureVisible(find.text('Next time'));
      await settle(tester);
      await binding.takeScreenshot('46-done');
      await tester.tap(find.text('Save'));
      // Done today: next time in three months, beyond Today's 30 days.
      await pumpUntil(tester, find.text('Nothing scheduled yet'));
      expect(find.byType(TodayRow), findsNothing);
      await settle(tester);
      await binding.takeScreenshot('47-today-after-done');

      // Barsik's Health tab: the plan moved, the record is in the history.
      await tester.tap(petsTab());
      await pumpUntil(tester, find.text('Upcoming'));
      final record = find.byType(RecordRow);
      await scrollTo(tester, record, scrollable: scrollableIn(HealthTab));
      await pumpUntil(
        tester,
        find.descendant(
          of: find.byType(HealthTab),
          matching: find.byIcon(Symbols.photo_rounded),
        ),
      );
      await settle(tester);
      await binding.takeScreenshot('48-health-after-done');

      // A past rabies vaccination, from the paper passport.
      final addRecord = find.text('Add past record');
      await scrollTo(tester, addRecord, scrollable: scrollableIn(HealthTab));
      await tester.tap(addRecord);
      await pumpUntil(tester, find.text('New record'));
      await tester.enterText(field('Title'), 'Rabies');
      await tester.tap(find.widgetWithText(FilterChip, 'Rabies'));
      await tester.enterText(field('Product'), 'Nobivac Rabies');
      await tester.enterText(field('Batch number'), 'A123');
      await hideKeyboard(tester);
      final validUntil = DateTime(now.year + 1, now.month, now.day - 1);
      await pickDate(tester, 'Valid until', validUntil);
      await tester.ensureVisible(find.text('Protects against'));
      await settle(tester);
      await binding.takeScreenshot('49-record-form');
      await tester.tap(find.text('Save'));
      await pumpUntil(tester, find.widgetWithText(RecordRow, 'Rabies'));

      // The passport's section V shows it.
      await tester.tap(find.text('Passport'));
      await pumpUntil(tester, find.byType(PassportTab));
      final rabiesRow = find.text('Nobivac Rabies · Batch A123');
      await scrollTo(
        tester,
        find.text('V. Rabies vaccination'),
        scrollable: scrollableIn(PassportTab),
      );
      await pumpUntil(tester, rabiesRow);
      await tester.ensureVisible(rabiesRow);
      await settle(tester);
      await binding.takeScreenshot('50-passport-rabies');

      // Delete Barsik, so reruns start clean.
      await tester.tap(find.byTooltip('More actions'));
      await pumpUntil(tester, find.text('Delete pet'));
      await tester.tap(find.text('Delete pet'));
      await pumpUntil(tester, find.text('Delete Barsik?'));
      await tester.tap(find.text('Delete'));
      await pumpUntil(tester, find.text('No pets yet'));
      await settle(tester);
      await binding.takeScreenshot('51-pets-after-delete');
    } finally {
      // Leave no test pets behind even when a step failed, and leave the
      // device as it was: signed out, with the previous developer email.
      if (find.byType(CollarbellApp).evaluate().isNotEmpty) {
        await deleteAllPets(tester);
      }
      await DevAuthRepository(prefs).signOut();
      if (previousEmail == null) {
        await prefs.remove(DevAuthRepository.lastEmailKey);
      } else {
        await prefs.setString(DevAuthRepository.lastEmailKey, previousEmail);
      }
    }
  });
}
