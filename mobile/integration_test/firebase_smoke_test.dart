// End-to-end smoke test with real Firebase sign-in against a running local API.
// Creates a throwaway account, checks that the API accepts its ID token, then
// deletes the account again.
//
//   cd backend && dotnet run --project src/Collarbell.AppHost
//   cd mobile && flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/firebase_smoke_test.dart -d <simulator> \
//     --dart-define=CB_API_BASE_URL=http://localhost:5080 --dart-define=CB_AUTH_MODE=firebase
import 'package:collarbell/features/notifications/push_platform.dart';
import 'package:collarbell/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a new Firebase account reaches the pets list through the API', (
    tester,
  ) async {
    await app.runCollarbell(
      overrides: [
        pushPlatformProvider.overrideWithValue(const DisabledPushPlatform()),
      ],
    );
    await FirebaseAuth.instance
        .signOut(); // start signed out, whatever an earlier run left

    final createAccountLink = find.text('New to Collarbell? Create an account');
    await pumpUntil(tester, createAccountLink);
    await tester.tap(createAccountLink);
    await settle(tester);

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'smoke+$stamp@collarbell.test');
    await tester.enterText(fields.at(1), 'Smoke-test-$stamp');
    FocusManager.instance.primaryFocus
        ?.unfocus(); // the keyboard covers the button
    await settle(tester);
    await binding.takeScreenshot('11-firebase-sign-up');
    await tester.tap(find.text('Create account'));

    try {
      // A new account with no pets: its onboarding opens over Home.
      await pumpUntil(
        tester,
        find.text('Reminders on time'),
        timeout: const Duration(seconds: 60),
      );
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      await tester.tap(petsTab());
      await pumpUntil(tester, find.text('No pets yet'));
      await settle(tester);
      await binding.takeScreenshot('12-firebase-pets-empty');
    } finally {
      // Leave no test accounts behind in the Firebase project.
      await FirebaseAuth.instance.currentUser?.delete();
    }
  });
}
