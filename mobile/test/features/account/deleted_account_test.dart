// The account was deleted elsewhere (another phone): the server answers its
// requests 401 account-deleted. Whichever request hears it, the app signs
// that account out of this phone once, cleans up what a sign-out cleans, and
// the sign-in screen says why. An answer to an account's last request can't
// sign out the next one, and a plain 401 signs out nobody. Firebase not
// knowing the account any more means the same; a sign-out that fails is
// tried again by the next such answer.
import 'dart:async';
import 'dart:convert';

import 'package:collarbell/app/app_config.dart';
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/data/api/api_providers.dart';
import 'package:collarbell/data/api/offline_cache.dart';
import 'package:collarbell/features/account/deleted_account.dart';
import 'package:collarbell/features/account/export_files.dart';
import 'package:collarbell/features/auth/auth_providers.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/me/me_repository.dart';
import 'package:collarbell/features/notifications/push_platform.dart';
import 'package:collarbell/l10n/app_localizations_en.dart';
import 'package:collarbell/shared/error_messages.dart';
import 'package:dio/dio.dart' show RequestOptions, ResponseBody;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api/api_client_test.dart' show FakeAdapter, problem;
import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const accountDeleted = {
  'type': ProblemTypes.accountDeleted,
  'title': 'This account has been deleted.',
  'status': 401,
};

/// Developer sign-in that counts its sign-outs. The next [failSignOuts]
/// fail (a locked keychain); with [gone] it can't renew the sign-in, as
/// Firebase can't for an account it no longer knows.
class _CountingAuth extends DevAuthRepository {
  _CountingAuth(super.prefs);

  var signOuts = 0;
  var failSignOuts = 0;
  var gone = false;

  @override
  Future<void> signOut() async {
    signOuts++;
    if (failSignOuts > 0) {
      failSignOuts--;
      throw PlatformException(code: 'keychain-error');
    }
    await super.signOut();
  }

  @override
  Future<Map<String, String>> authHeaders() async {
    if (gone && currentUser != null) throw const SignInAccountGone();
    return super.authHeaders();
  }
}

void main() {
  group('the app', () {
    late ProviderContainer container;
    late _CountingAuth auth;
    late FakePushPlatform push;
    late MemoryOfflineCacheStore copies;
    late FakeExportFiles exports;
    late SharedPreferences prefs;
    late Future<ResponseBody> Function(RequestOptions options) answer;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        DevAuthRepository.uidKey: 'dev-1',
        DevAuthRepository.emailKey: 'anna@example.com',
        CurrentHouseholdNotifier.keyFor('dev-1'): jsonEncode(
          const CurrentHousehold(id: 'home', name: 'Home').toJson(),
        ),
      });
      prefs = await SharedPreferences.getInstance();
      auth = _CountingAuth(prefs);
      push = FakePushPlatform();
      exports = FakeExportFiles();
      copies = MemoryOfflineCacheStore()
        ..entries['dev-1 home /api/v1/pets?'] = CachedAnswer(
          const [],
          DateTime(2026, 10, 6),
        );
      container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://api.test',
              authMode: AuthMode.dev,
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          offlineCacheStoreProvider.overrideWithValue(copies),
          authRepositoryProvider.overrideWithValue(auth),
          pushPlatformProvider.overrideWithValue(push),
          exportFilesProvider.overrideWithValue(exports),
        ],
      );
      addTearDown(container.dispose);
      answer = (_) async => problem(401, accountDeleted);
      container.read(apiClientProvider).dio.httpClientAdapter = FakeAdapter(
        (options) => answer(options),
      );
    });

    Future<void> listPets() async {
      try {
        await container
            .read(apiClientProvider)
            .send((api) => api.pets.listPets());
      } on ApiException {
        // Looked at through what the app did.
      }
    }

    /// Waits for the sign-out a request started (a second call joins it);
    /// true when the phone is signed out of [uid].
    Future<bool> signedOut(String uid) =>
        container.read(deletedAccountProvider.notifier).signOut(uid);

    test('whichever requests hear it, the account signs out here once, and '
        'what a sign-out cleans is clean', () async {
      await Future.wait([listPets(), listPets(), listPets()]);
      await signedOut('dev-1');

      expect(auth.signOuts, 1);
      expect(container.read(authUserProvider), isNull);
      expect(container.read(deletedAccountProvider), isTrue);
      expect(push.tokensForgotten, 1);
      expect(copies.entries, isEmpty);
      expect(exports.clearAlls, 1);
      expect(prefs.getString(CurrentHouseholdNotifier.keyFor('dev-1')), isNull);

      // Its requests still on their way change nothing more.
      await listPets();
      expect(auth.signOuts, 1);
    });

    test(
      "an answer to the last account's request signs out nobody new",
      () async {
        final sent = Completer<void>();
        final late = Completer<ResponseBody>();
        answer = (_) {
          sent.complete();
          return late.future;
        };
        final request = listPets();
        await sent.future;

        // Meanwhile that account signed out, and someone else signed in.
        await auth.signOut();
        await auth.signInAsDeveloper('boris@example.com');
        await Future<void>.delayed(Duration.zero);
        late.complete(problem(401, accountDeleted));
        await request;
        await Future<void>.delayed(Duration.zero);

        expect(container.read(authUserProvider)?.email, 'boris@example.com');
        expect(container.read(deletedAccountProvider), isFalse);
        expect(auth.signOuts, 1);
      },
    );

    test('a sign-out that fails is forgotten: the next answer that the '
        'account is gone tries again', () async {
      auth.failSignOuts = 1;
      // The sign-outs the answers start run on their own: a moment for them.
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 10));

      await listPets();
      await settle();
      expect(auth.signOuts, 1);
      expect(container.read(authUserProvider), isNotNull);
      // The rest of the cleanup was done all the same.
      expect(copies.entries, isEmpty);
      expect(exports.clearAlls, 1);

      await listPets();
      await settle();
      expect(auth.signOuts, 2);
      expect(container.read(authUserProvider), isNull);
      expect(container.read(deletedAccountProvider), isTrue);

      // Done: later answers join it.
      await listPets();
      await settle();
      expect(auth.signOuts, 2);
    });

    test("Firebase can't renew the sign-in (it doesn't know the account): "
        'the same as the server saying the account is gone', () async {
      auth.gone = true;
      Object? failure;
      try {
        await container
            .read(apiClientProvider)
            .send((api) => api.pets.listPets());
      } on ApiException catch (error) {
        failure = error;
      }
      expect(await signedOut('dev-1'), isTrue);

      expect(isAccountDeleted(failure!), isTrue);
      expect(
        errorMessageFor(failure, AppLocalizationsEn()),
        'Your account has been deleted.',
      );
      expect(container.read(authUserProvider), isNull);
      expect(container.read(deletedAccountProvider), isTrue);
      expect(copies.entries, isEmpty);
    });

    test('Firebase signed the account out by itself before the answer came: '
        'the phone still cleans up, and says why', () async {
      final sent = Completer<void>();
      final late = Completer<ResponseBody>();
      answer = (_) {
        sent.complete();
        return late.future;
      };
      final request = listPets();
      await sent.future;
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);

      late.complete(problem(401, accountDeleted));
      await request;
      await signedOut('dev-1');

      expect(container.read(deletedAccountProvider), isTrue);
      expect(push.tokensForgotten, 1);
      expect(copies.entries, isEmpty);
      expect(prefs.getString(CurrentHouseholdNotifier.keyFor('dev-1')), isNull);
    });

    test('a plain 401 signs out nobody', () async {
      answer = (_) async =>
          problem(401, {'title': 'Unauthorized', 'status': 401});

      await listPets();
      await Future<void>.delayed(Duration.zero);

      expect(auth.signOuts, 0);
      expect(container.read(deletedAccountProvider), isFalse);
      expect(container.read(authUserProvider), isNotNull);
    });

    test('signing in ends the message, and the same account (a developer '
        "e-mail) hears of its deletion again", () async {
      await listPets();
      await signedOut('dev-1');
      expect(container.read(deletedAccountProvider), isTrue);

      final again = await auth.signInAsDeveloper('anna@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(deletedAccountProvider), isFalse);

      for (var time = 2; time <= 3; time++) {
        await listPets();
        await signedOut(again.uid);
        expect(auth.signOuts, time);
        expect(container.read(deletedAccountProvider), isTrue);
        await auth.signInAsDeveloper('anna@example.com');
        await Future<void>.delayed(Duration.zero);
      }
    });
  });

  testWidgets('a usual sign-out deletes the copies of a data export too', (
    tester,
  ) async {
    final exports = FakeExportFiles();
    await pumpApp(
      tester,
      location: AppRoutes.more,
      overrides: fakeRepositories(exportFiles: exports),
    );

    await tester.scrollUntilVisible(find.text('Sign out'), 300);
    await tapVisible(tester, find.text('Sign out'));
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(find.text('Continue as developer'), findsOneWidget);
    expect(exports.clearAlls, 1);
  });

  testWidgets('the sign-in screen says the account is gone, until someone '
      'signs in', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.more,
      overrides: fakeRepositories(),
    );
    final client = appContainer(tester).read(apiClientProvider);
    client.dio.httpClientAdapter = FakeAdapter(
      (_) async => problem(401, accountDeleted),
    );

    // Another phone deleted the account: this one's next request hears it.
    // (Out of the test's fake time: dio waits for real timers.)
    await tester.runAsync(() async {
      try {
        await ApiMeRepository(client).getMe();
      } on ApiException catch (error) {
        expect(error.problemType, ProblemTypes.accountDeleted);
      }
      // The sign-out the answer started.
      await appContainer(
        tester,
      ).read(deletedAccountProvider.notifier).signOut(testUid);
    });
    await tester.pumpAndSettle();

    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(find.text('Continue as developer'), findsOneWidget);

    await tapVisible(tester, find.text('Continue as developer'));
    // In, as an account new on this phone: its onboarding over Home.
    expect(find.text('Reminders on time'), findsOneWidget);
    await appContainer(tester).read(authRepositoryProvider).signOut();
    await tester.pumpAndSettle();

    expect(find.text('Continue as developer'), findsOneWidget);
    expect(find.text('Your account has been deleted.'), findsNothing);
  });
}
