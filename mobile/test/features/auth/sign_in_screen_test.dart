// "Forgot password?": a link to the e-mail typed above, in the app's
// language, without saying whether the account exists.
import 'package:collarbell/app/app.dart';
import 'package:collarbell/app/app_config.dart';
import 'package:collarbell/app/live_updates.dart';
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/features/auth/auth_providers.dart';
import 'package:collarbell/features/auth/auth_repository.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/theme/collarbell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

/// Dev sign-in that also "sends" password links, recording them.
class _RecordingAuth extends DevAuthRepository {
  _RecordingAuth(super.prefs);

  final resets = <(String, String?)>[];
  AuthFailure? resetFailure;

  @override
  Future<void> sendPasswordReset(String email, {String? languageCode}) async {
    if (resetFailure case final failure?) throw AuthException(failure);
    resets.add((email, languageCode));
  }
}

void main() {
  late _RecordingAuth auth;

  Future<void> pumpSignIn(WidgetTester tester, {String language = 'en'}) async {
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'settings.language': language});
    final prefs = await SharedPreferences.getInstance();
    auth = _RecordingAuth(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:5080',
              authMode: AuthMode.dev,
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          fontResolverProvider.overrideWithValue(plainFontResolver),
          authRepositoryProvider.overrideWithValue(auth),
          realtimeClientFactoryProvider.overrideWithValue(
            FakeLiveServer().newClient,
          ),
        ],
        retry: noAutomaticRetry,
        child: const CollarbellApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder emailField() => find.byType(TextFormField).at(1);

  Future<void> tapForgot(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('a link goes to the e-mail above, in the app language', (
    tester,
  ) async {
    await pumpSignIn(tester, language: 'ru');
    await tester.enterText(emailField(), ' anna@example.com ');

    await tapForgot(tester, 'Забыли пароль?');

    expect(auth.resets, [('anna@example.com', 'ru')]);
    expect(
      find.textContaining('Если аккаунт с адресом anna@example.com есть'),
      findsOneWidget,
    );
  });

  testWidgets('no e-mail yet: says where to type it, sends nothing', (
    tester,
  ) async {
    await pumpSignIn(tester);

    await tapForgot(tester, 'Forgot password?');

    expect(auth.resets, isEmpty);
    expect(
      find.text(
        'Enter your e-mail above: the link for a new password goes there.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('too many tries: the reason, not a silent nothing', (
    tester,
  ) async {
    await pumpSignIn(tester);
    auth.resetFailure = AuthFailure.tooManyRequests;
    await tester.enterText(emailField(), 'anna@example.com');

    await tapForgot(tester, 'Forgot password?');

    expect(find.textContaining('Too many attempts'), findsOneWidget);
  });

  testWidgets('creating an account has no "Forgot password?"', (tester) async {
    await pumpSignIn(tester);
    final toggle = find.text('New to Collarbell? Create an account');
    // The list builds rows only as they come close to the screen.
    await tester.scrollUntilVisible(
      toggle,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('Forgot password?'), findsNothing);
  });
}
