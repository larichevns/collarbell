import 'package:collarbell/app/app.dart';
import 'package:collarbell/app/app_config.dart';
import 'package:collarbell/app/live_updates.dart';
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_providers.dart';
import 'package:collarbell/data/api/offline_cache.dart';
import 'package:collarbell/features/account/export_files.dart';
import 'package:collarbell/features/ai/ai_repository.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/billing/billing_repository.dart';
import 'package:collarbell/features/me/me_repository.dart';
import 'package:collarbell/features/me/profile_sync.dart';
import 'package:collarbell/features/onboarding/onboarding.dart';
import 'package:collarbell/features/onboarding/welcome_screen.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/features/today/today_repository.dart';
import 'package:collarbell/theme/collarbell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  group('authRedirect', () {
    test('sends signed-out users to sign-in', () {
      expect(
        authRedirect(signedIn: false, location: AppRoutes.pets),
        AppRoutes.signIn,
      );
      expect(authRedirect(signedIn: false, location: AppRoutes.signIn), isNull);
    });

    test('keeps signed-in users away from sign-in: they land on Home', () {
      expect(
        authRedirect(signedIn: true, location: AppRoutes.signIn),
        AppRoutes.home,
      );
      expect(authRedirect(signedIn: true, location: AppRoutes.more), isNull);
    });
  });

  group('app in dev auth mode', () {
    late FakeMeRepository me;
    late FakePetsRepository pets;

    /// Pumps the whole app; [size] is the screen in logical pixels.
    Future<void> pumpApp(
      WidgetTester tester, {
      Size size = const Size(390, 844),
    }) async {
      tester.view
        ..physicalSize = size * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      me = FakeMeRepository();
      pets = FakePetsRepository();
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                apiBaseUrl: 'http://localhost:5080',
                authMode: AuthMode.dev,
              ),
            ),
            // Widget tests have no app storage folder (a plugin).
            offlineCacheStoreProvider.overrideWithValue(
              MemoryOfflineCacheStore(),
            ),
            // Nor a temporary one: sign-out deletes the export copies there.
            exportFilesProvider.overrideWithValue(FakeExportFiles()),
            sharedPreferencesProvider.overrideWithValue(prefs),
            fontResolverProvider.overrideWithValue(plainFontResolver),
            meRepositoryProvider.overrideWithValue(me),
            petsRepositoryProvider.overrideWithValue(pets),
            todayRepositoryProvider.overrideWithValue(FakeTodayRepository()),
            aiRepositoryProvider.overrideWithValue(FakeAiRepository()),
            billingRepositoryProvider.overrideWithValue(
              FakeBillingRepository(),
            ),
            deviceTimeZoneProvider.overrideWithValue(
              () async => 'Europe/Berlin',
            ),
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

    /// The app's router.
    GoRouter appRouterOf(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(CollarbellApp)),
    ).read(routerProvider);

    /// Scrolls [finder] into view (ListView builds rows beyond the screen
    /// edge, so being in the tree is not enough) and taps it.
    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));
    // The onboarding's pages are tapped through faster than a person
    // would: its button doesn't wait after each page.
    setUpAll(() => WelcomeScreen.settleAfterMove = Duration.zero);
    tearDownAll(
      () => WelcomeScreen.settleAfterMove = const Duration(milliseconds: 300),
    );

    testWidgets('signs in as developer, syncs the profile, loads pets', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Continue as developer'), findsOneWidget);
      final uid = DevAuthRepository.uidForEmail(DevAuthRepository.defaultEmail);
      expect(find.text('User ID: $uid'), findsOneWidget);

      await tapVisible(tester, find.text('Continue as developer'));

      // A new account with no pets: the onboarding opens on top of Home.
      expect(find.text('Reminders on time'), findsOneWidget);
      expect(me.updates, [(locale: 'en', timeZone: 'Europe/Berlin')]);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // Home, the first tab: adding a pet comes first.
      expect(appRouterOf(tester).state.matchedLocation, AppRoutes.home);
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      // Today: title and navigation label; it says to start with a pet.
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsNWidgets(2));
      expect(find.text('Start with a pet'), findsOneWidget);

      await tester.tap(find.text('Pets'));
      await tester.pumpAndSettle();

      expect(find.text('No pets yet'), findsOneWidget);
      expect(pets.calls, 1);
    });

    testWidgets('a restored session skips sign-in; sign-out returns to it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        DevAuthRepository.uidKey: 'dev-0000000000000001',
        DevAuthRepository.emailKey: 'anna@example.com',
        // Shown at an earlier start.
        OnboardingTurn.keyFor('dev-0000000000000001'): true,
      });
      await pumpApp(tester);

      // Straight to Home, without the onboarding again.
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.text('Reminders on time'), findsNothing);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('anna@example.com'), findsOneWidget);

      // The list builds its rows as they scroll into view.
      await tester.scrollUntilVisible(find.text('Sign out'), 300);
      expect(find.text('Reading photos with AI'), findsOneWidget);
      expect(find.text('Not set up'), findsOneWidget);
      await tapVisible(tester, find.text('Sign out'));
      // It asks first.
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();

      expect(find.text('Continue as developer'), findsOneWidget);
    });

    testWidgets('fits a small phone in Russian (no overflow)', (tester) async {
      SharedPreferences.setMockInitialValues({'settings.language': 'ru'});
      await pumpApp(tester, size: const Size(360, 640));

      expect(find.text('Продолжить как разработчик'), findsOneWidget);
      await tapVisible(tester, find.text('Продолжить как разработчик'));

      // The onboarding: its pages, then the pet step.
      expect(find.text('Напомним вовремя'), findsOneWidget);
      for (var page = 0; page < 3; page++) {
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }
      expect(find.text('Кто у вас живёт?'), findsOneWidget);
      // Back to the pages, and closed from the first.
      for (var back = 0; back < 3; back++) {
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.text('Добавьте питомца'), findsOneWidget);

      for (final tab in ['Сегодня', 'Питомцы', 'Запасы', 'Ещё']) {
        await tapVisible(tester, find.text(tab).last);
      }
      expect(find.text('Мой дом'), findsOneWidget);
      // The list builds its rows as they scroll into view.
      await tester.scrollUntilVisible(find.text('Светлая (по умолчанию)'), 300);
      expect(find.text('Светлая (по умолчанию)'), findsOneWidget);

      await tapVisible(tester, find.text('Тёмная'));
      await tapVisible(tester, find.text('Питомцы').last);
      expect(find.text('Пока нет питомцев'), findsOneWidget);
    });

    testWidgets('validates the email and password fields', (tester) async {
      await pumpApp(tester);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);

      await tapVisible(
        tester,
        find.text('New to Collarbell? Create an account'),
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(2), 'short');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Create account'),
      );

      expect(find.text('Enter an email like name@example.com'), findsOneWidget);
      expect(find.text('Use at least 8 characters'), findsOneWidget);
    });
  });
}
