// Every request names the household on screen (X-Household), or the one a
// change was made on (pinned); a refusal because the user isn't in it any
// more takes the app back to their first household, one because of the role
// asks /me for the role again; the household endpoints send what the server
// expects.
import 'dart:convert';

import 'package:collarbell/app/app_config.dart';
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/data/api/api_providers.dart';
import 'package:collarbell/data/api/household_header.dart';
import 'package:collarbell/data/api/offline_cache.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/household/household_repository.dart';
import 'package:collarbell/l10n/app_localizations_en.dart';
import 'package:collarbell/l10n/app_localizations_ru.dart';
import 'package:collarbell/shared/error_messages.dart';
import 'package:dio/dio.dart' show RequestOptions, ResponseBody;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client_test.dart' show FakeAdapter, json, problem, petJson;

const notAMember = {
  'type': ProblemTypes.notAHouseholdMember,
  'title': "You aren't in this household.",
  'status': 403,
};

const roleRefused = {
  'type': ProblemTypes.roleForbidden,
  'title': "Your role in this household can't do this.",
  'status': 403,
};

void main() {
  group('the API client', () {
    late String? household;
    late List<String> lost;
    late int roleRefusals;

    ApiClient client(FakeAdapter adapter) => ApiClient(
      baseUrl: 'http://api.test',
      authHeaders: () async => {'X-Dev-User': 'dev-1'},
      household: () => household,
      onNotAMember: lost.add,
      onRoleRefused: () => roleRefusals++,
      httpClientAdapter: adapter,
    );

    setUp(() {
      household = null;
      lost = [];
      roleRefusals = 0;
    });

    test('every request names the household on screen; none until the app '
        'knows it', () async {
      final adapter = FakeAdapter((_) async => json([petJson()], 200));
      final api = client(adapter);

      await api.send((api) => api.pets.listPets());
      household = 'home';
      await api.send((api) => api.pets.listPets());
      household = 'office';
      await api.send((api) => api.pets.listPets());

      expect(
        [for (final r in adapter.requests) r.headers[householdHeader]],
        [null, 'home', 'office'],
      );
    });

    test('a refusal for a household the user left says which one', () async {
      household = 'office';
      final adapter = FakeAdapter((_) async => problem(403, notAMember));

      await expectLater(
        client(adapter).send((api) => api.pets.listPets()),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.forbidden)
              .having(
                (e) => e.problemType,
                'type',
                ProblemTypes.notAHouseholdMember,
              ),
        ),
      );
      expect(lost, ['office']);
      expect(roleRefusals, 0);
    });

    test('a change pinned to a household goes there, whatever is on screen '
        'when it is sent', () async {
      household = 'home';
      final adapter = FakeAdapter((_) async => json([petJson()], 200));
      final api = client(adapter);

      await api.send((api) => api.pets.listPets(), household: 'office');
      await inHousehold('office', () async {
        // A form's save: everything it sends, after any await.
        await api.send((api) => api.pets.listPets());
        await Future<void>.delayed(Duration.zero);
        await api.send((api) => api.pets.listPets());
      });
      await api.send((api) => api.pets.listPets());

      expect(
        [for (final r in adapter.requests) r.headers[householdHeader]],
        ['office', 'office', 'office', 'home'],
      );
    });

    test('a pinned change refused for a household the user left reports '
        'that household', () async {
      household = 'home';
      final adapter = FakeAdapter((_) async => problem(403, notAMember));

      await expectLater(
        client(adapter).send((api) => api.pets.listPets(), household: 'office'),
        throwsA(isA<ApiException>()),
      );

      expect(lost, ['office']);
    });

    test("a role's refusal is not about the household, and says so", () async {
      household = 'home';
      final adapter = FakeAdapter((_) async => problem(403, roleRefused));

      Object? error;
      try {
        await client(adapter).send((api) => api.pets.listPets());
      } catch (e) {
        error = e;
      }

      expect(lost, isEmpty);
      expect(roleRefusals, 1);
      expect(
        errorMessageFor(error!, AppLocalizationsRu()),
        'Ваша роль в группе не позволяет это сделать.',
      );
      expect(
        errorMessageFor(error, AppLocalizationsEn()),
        "Your role in the group doesn't allow this.",
      );
    });
  });

  group('the app', () {
    late ProviderContainer container;
    late FakeAdapter adapter;
    late ResponseBody Function(RequestOptions options) answer;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        DevAuthRepository.uidKey: 'dev-1',
        DevAuthRepository.emailKey: 'anna@example.com',
      });
      final preferences = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://api.test',
              authMode: AuthMode.dev,
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          offlineCacheStoreProvider.overrideWithValue(
            MemoryOfflineCacheStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
      answer = (_) => json([petJson()], 200);
      adapter = FakeAdapter((options) async => answer(options));
      container.read(apiClientProvider).dio.httpClientAdapter = adapter;
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

    test('sends the household picked, and another after a switch; the '
        'choice is saved per account', () async {
      final household = container.read(currentHouseholdProvider.notifier);
      household.switchTo(const CurrentHousehold(id: 'home'));
      await listPets();
      household.switchTo(
        const CurrentHousehold(
          id: 'office',
          name: 'Office',
          role: HouseholdRole.helper,
        ),
      );
      await listPets();

      expect(
        [for (final r in adapter.requests) r.headers[householdHeader]],
        ['home', 'office'],
      );
      final saved = (await SharedPreferences.getInstance()).getString(
        CurrentHouseholdNotifier.keyFor('dev-1'),
      );
      expect(jsonDecode(saved!), {
        'id': 'office',
        'name': 'Office',
        'role': 'helper',
      });
    });

    test('removed from the household on screen: back to the server\'s '
        'choice, with a message', () async {
      container
          .read(currentHouseholdProvider.notifier)
          .switchTo(const CurrentHousehold(id: 'office', name: 'Office'));
      answer = (_) => problem(403, notAMember);

      await listPets();

      expect(container.read(currentHouseholdProvider), isNull);
      final notice = container.read(householdNoticeProvider);
      expect((notice as HouseholdLeft?)?.id, 'office');
      expect(notice?.name, 'Office');
      answer = (_) => json([petJson()], 200);
      await listPets();
      expect(adapter.requests.last.headers[householdHeader], isNull);
    });

    test("a role's refusal asks /me for the role again", () async {
      container.listen(roleCheckProvider, (_, _) {});
      answer = (_) => problem(403, roleRefused);

      await listPets();

      expect(container.read(roleCheckProvider), 1);
    });

    test('the household endpoints: the code goes in the body, the answers '
        'become the app\'s households', () async {
      container
          .read(currentHouseholdProvider.notifier)
          .switchTo(const CurrentHousehold(id: 'home'));
      answer = (options) => switch (options.path) {
        '/api/v1/invites/preview' => json({
          'householdName': 'Home',
          'invitedBy': 'Anna',
          'role': 'Helper',
          'expiresAt': '2026-10-12T14:00:00+00:00',
          'alreadyMember': false,
        }, 200),
        '/api/v1/invites/accept' => json({
          'id': 'joined',
          'name': 'Home',
          'role': 'Helper',
          'timeZone': 'Europe/Berlin',
          'memberCount': 3,
        }, 200),
        _ => json({
          'id': 'home',
          'name': 'Home',
          'timeZone': 'Europe/Berlin',
          'timeZoneSetByHand': false,
          'role': 'Owner',
          'members': [
            {
              'userId': 'u1',
              'displayName': 'Anna',
              'email': null,
              'role': 'Owner',
              'joinedAt': '2026-10-01T10:00:00+00:00',
              'isMe': true,
            },
          ],
          'invites': [
            {
              'id': 'i1',
              'code': 'ABCD-2345',
              'role': 'Member',
              'createdAt': '2026-10-05T10:00:00+00:00',
              'expiresAt': '2026-10-12T10:00:00+00:00',
            },
          ],
        }, 200),
      };
      final repository = container.read(householdRepositoryProvider);

      final preview = await repository.previewInvite('ABCD2345');
      final joined = await repository.acceptInvite('ABCD2345');
      final details = await repository.getCurrent();

      final [previewed, accepted, current] = adapter.requests;
      expect(previewed.method, 'POST');
      expect(previewed.data, {'code': 'ABCD2345'});
      expect(accepted.path, '/api/v1/invites/accept');
      expect(accepted.data, {'code': 'ABCD2345'});
      expect(current.path, '/api/v1/households/current');
      expect(preview.invitedBy, 'Anna');
      expect(preview.role, HouseholdRole.helper);
      expect(preview.alreadyMember, isFalse);
      expect(joined.memberCount, 3);
      expect(details.role, HouseholdRole.owner);
      expect(details.members.single.isMe, isTrue);
      expect(details.invites.single.role, HouseholdRole.member);
      expect(details.invites.single.code, 'ABCD-2345');
    });
  });
}
