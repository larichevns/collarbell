// End-to-end test of milestone M1 against a running local API (dev sign-in):
// add a pet with a photo, add a passport page, see it in the Passport and
// Documents tabs, delete the pet. A fake picker returns pictures drawn at
// runtime instead of opening the camera or the photo library.
//
//   cd backend && dotnet run --project src/Collarbell.AppHost
//   cd mobile && flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/pets_passport_test.dart -d <simulator> \
//     --dart-define=CB_API_BASE_URL=http://localhost:5080
//
// Screenshots are written to build/screenshots/.

import 'package:collarbell/app/app.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/files/media_picker.dart';
import 'package:collarbell/features/files/widgets/stored_file_image.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pets_screen.dart';
import 'package:collarbell/features/pets/widgets/pet_avatar.dart';
import 'package:collarbell/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collarbell/features/notifications/push_platform.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// The test's own developer account: its household holds only test pets,
/// so cleaning up never touches pets added by hand.
const testEmail = 'e2e-pets@collarbell.local';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('adds a pet and a passport page, then deletes the pet', (
    tester,
  ) async {
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
      await binding.takeScreenshot('21-sign-in');
      await tester.tap(continueAsDeveloper);
      // Signed in: Home, with the tab bar.
      await pumpUntil(tester, petsTab());

      // A crashed earlier run may have left a pet behind.
      await deleteAllPets(tester);

      await tester.tap(petsTab());
      await pumpUntil(tester, find.text('No pets yet'));
      await settle(tester);
      await binding.takeScreenshot('22-pets-empty');

      // Add Murka through the form.
      await tester.tap(find.text('Add pet'));
      await pumpUntil(tester, find.text('New pet'));
      await tester.enterText(field('Name'), 'Murka');
      await tester.tap(find.text('Female'));
      await tester.enterText(field('Breed'), 'British Shorthair');
      await hideKeyboard(tester);
      await binding.takeScreenshot('23-pet-form');
      await tester.tap(find.text('Save'));
      await pumpUntil(tester, find.text('Murka'));
      await settle(tester);
      await binding.takeScreenshot('24-pets-list');

      // Open her and give her a photo.
      await tester.tap(find.text('Murka'));
      await pumpUntil(tester, find.text('Overview'));
      await settle(tester);
      await binding.takeScreenshot('25-pet-overview');

      await tester.tap(find.text('Add photo'));
      await pumpUntil(tester, find.text('Choose from library'));
      await tester.tap(find.text('Choose from library'));
      await pumpUntil(
        tester,
        find.descendant(of: find.byType(PetAvatar), matching: loadedImage),
      );
      await settle(tester);
      await binding.takeScreenshot('26-pet-photo');

      // Add a passport page.
      await tester.tap(find.text('Passport'));
      final addPages = find.text('Add pages');
      await pumpUntil(tester, find.byType(PassportTab));
      await tester.scrollUntilVisible(
        addPages,
        300,
        scrollable: find
            .descendant(
              of: find.byType(PassportTab),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await settle(tester);
      await binding.takeScreenshot('27-passport-empty');

      await tester.tap(addPages);
      await pumpUntil(tester, find.text('Choose from library'));
      await settle(tester);
      await binding.takeScreenshot('28-add-pages-sheet');
      await tester.tap(find.text('Choose from library'));
      // The thumbnail is on screen once the upload, the document and the
      // picture itself have arrived.
      await pumpUntil(
        tester,
        find.descendant(of: find.byType(PageTile), matching: loadedImage),
      );
      await settle(tester);
      await binding.takeScreenshot('29-passport-page');

      // The page in the full-screen viewer.
      await tester.tap(find.byType(PageTile));
      await pumpUntil(tester, find.text('Page 1 of 1'));
      await pumpUntil(tester, loadedImage);
      await settle(tester);
      await binding.takeScreenshot('30-page-viewer');
      await tester.tap(find.byTooltip('Close'));
      await pumpUntil(tester, find.byType(PassportTab));
      await settle(tester);

      // The Documents tab lists the passport pages.
      await tester.tap(find.text('Documents'));
      await pumpUntil(tester, find.text('Passport pages'));
      await settle(tester);
      expect(find.textContaining('1\u00A0page'), findsOneWidget);
      await binding.takeScreenshot('31-documents');

      // The list shows her photo.
      await tester.tap(find.byTooltip('Back'));
      await pumpUntil(
        tester,
        find.descendant(of: find.byType(PetRow), matching: loadedImage),
      );
      await settle(tester);
      await binding.takeScreenshot('32-pets-list-photo');
      await tester.tap(find.text('Murka'));
      await pumpUntil(tester, find.text('Overview'));
      await settle(tester);

      // Delete her, so reruns start clean.
      await tester.tap(find.byTooltip('More actions'));
      await pumpUntil(tester, find.text('Delete pet'));
      await tester.tap(find.text('Delete pet'));
      await pumpUntil(tester, find.text('Delete Murka?'));
      await settle(tester);
      await binding.takeScreenshot('33-delete-pet');
      await tester.tap(find.text('Delete'));
      await pumpUntil(tester, find.text('No pets yet'));
      await settle(tester);
      await binding.takeScreenshot('34-pets-after-delete');
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
