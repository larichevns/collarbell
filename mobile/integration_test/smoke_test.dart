// End-to-end smoke test against a running local API (dev sign-in).
//
//   cd backend && dotnet run --project src/Collarbell.AppHost
//   cd mobile && flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/smoke_test.dart -d <simulator> \
//     --dart-define=CB_API_BASE_URL=http://localhost:5080
//
// Screenshots are written to build/screenshots/.
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/notifications/push_platform.dart';
import 'package:collarbell/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('developer signs in and sees the empty pets list from the API', (
    tester,
  ) async {
    // Whichever developer account signs in: no onboarding over Home.
    final prefs = await SharedPreferences.getInstance();
    await skipOnboarding(
      prefs,
      prefs.getString(DevAuthRepository.lastEmailKey) ??
          DevAuthRepository.defaultEmail,
    );
    await app.runCollarbell(
      overrides: [
        pushPlatformProvider.overrideWithValue(const DisabledPushPlatform()),
      ],
    );

    // A session saved by an earlier run skips the sign-in screen.
    final continueAsDeveloper = find.text('Continue as developer');
    await pumpUntil(tester, find.byType(Scaffold));
    if (await appears(
      tester,
      continueAsDeveloper,
      const Duration(seconds: 5),
    )) {
      await settle(tester);
      await binding.takeScreenshot('01-sign-in');
      await tester.tap(continueAsDeveloper);
    }

    // Signed in: Home; Today has nothing yet.
    await pumpUntil(tester, todayTab());
    await tester.tap(todayTab());
    await pumpUntil(tester, find.text('Nothing scheduled yet'));
    await settle(tester);
    await binding.takeScreenshot('02-today');

    await tester.tap(petsTab());
    await pumpUntil(tester, find.text('No pets yet'));
    await settle(tester);
    await binding.takeScreenshot('03-pets-empty');
  });
}
