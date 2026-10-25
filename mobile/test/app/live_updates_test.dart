// Live updates (app/live_updates.dart): while the app is in front it keeps a
// connection to the server's hub, signed in like its requests and naming
// the household on screen; a moment away (the camera, the photo picker)
// keeps it, 30 seconds away closes it. A change made elsewhere reads again
// the screens that show it (300 ms of changes in one go); the app's own
// changes are skipped (only the phone that made a change gets its id back).
// A failed or dropped connection is tried again after 1, 2, 5, 10 and 30
// seconds, every time with fresh sign-in headers; a refusal isn't, until
// another household or the app comes back to the front. Connected again,
// the household's screens are read again; without a connection, Today
// every 30 seconds.
import 'dart:async';

import 'package:collarbell/app/app_config.dart';
import 'package:collarbell/app/live_updates.dart';
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/app_session.dart';
import 'package:collarbell/data/live/realtime_client.dart';
import 'package:collarbell/features/ai/ai_repository.dart';
import 'package:collarbell/features/auth/auth_providers.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/billing/billing_repository.dart';
import 'package:collarbell/features/care/care_repository.dart';
import 'package:collarbell/features/feeding/feeding_repository.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/me/me_repository.dart';
import 'package:collarbell/features/me/profile_sync.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/supplies/supplies_repository.dart';
import 'package:collarbell/features/today/today_repository.dart';
import 'package:collarbell/features/visits/visits_repository.dart';
import 'package:collarbell/features/weight/weight_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/pump.dart';

const _notAMember = RealtimeRefused("You aren't in this household.");

/// `/me` that waits for [gate] before the profile sync's answer.
class _SlowSyncMe extends FakeMeRepository {
  final gate = Completer<void>();

  @override
  Future<UserProfile> updateMe({
    String? displayName,
    String? locale,
    String? timeZone,
  }) async {
    await gate.future;
    return super.updateMe(locale: locale, timeZone: timeZone);
  }
}

/// The app goes to the background.
void _away(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// The app comes back to the front.
void _back(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  group('the connection', () {
    late FakeLiveServer server;
    late List<Set<String>> changed;
    late List<bool> readAgain;
    late int polls;
    late int signIns;

    LiveUpdates liveUpdates() => LiveUpdates(
      newClient: server.newClient,
      url: Uri.parse('http://api.test/hubs/household'),
      // A new token every time, as Firebase gives one after the old expired.
      authHeaders: () async => {'Authorization': 'Bearer token-${++signIns}'},
      onChanged: changed.add,
      onReconnected: ({required backInApp}) => readAgain.add(backInApp),
      pollToday: () => polls++,
      clientId: 'this-phone',
    );

    /// Signed in, in the household h1, in front: connected.
    LiveUpdates connected(FakeAsync async) {
      final live = liveUpdates()
        ..update(user: 'u1', household: 'h1', inFront: true);
      async.flushMicrotasks();
      expect(live.status, LiveStatus.live);
      return live;
    }

    List<String?> tokens() => [
      for (final client in server.clients) client.headers?['Authorization'],
    ];

    setUp(() {
      server = FakeLiveServer();
      changed = [];
      readAgain = [];
      polls = 0;
      signIns = 0;
    });

    test('opens with the sign-in, the household on screen and this '
        "launch's id; the first connection reads nothing again", () {
      fakeAsync((async) {
        final live = connected(async);

        final client = server.clients.single;
        expect(client.url, Uri.parse('http://api.test/hubs/household'));
        expect(client.headers, {
          'Authorization': 'Bearer token-1',
          'X-Household': 'h1',
          'X-Client': 'this-phone',
        });
        async.elapse(const Duration(minutes: 5));
        expect(readAgain, isEmpty);
        expect(polls, 0);
        live.dispose();
        expect(client.closed, isTrue);
      });
    });

    test("skips the app's own changes; the others' are collected for "
        '300 ms and read in one go', () {
      fakeAsync((async) {
        final live = connected(async);

        server.change([LiveTopics.feeding], origin: 'this-phone');
        // Another phone's: the server names no origin to anyone else.
        server.change([LiveTopics.feeding]);
        server.change([LiveTopics.care]);
        async.elapse(const Duration(milliseconds: 299));
        expect(changed, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(changed, [
          {LiveTopics.feeding, LiveTopics.care},
        ]);

        // An id that isn't this launch's (an earlier launch, the same
        // person's tablet) is read like any change.
        server.change([LiveTopics.visits], origin: 'other-launch');
        async.elapse(const Duration(seconds: 1));
        expect(changed.last, {LiveTopics.visits});

        // Its own alone: nothing to read.
        server.change([LiveTopics.pets], origin: 'this-phone');
        async.elapse(const Duration(seconds: 1));
        expect(changed, hasLength(2));

        // A change it couldn't read: anything may have changed.
        server.change([]);
        async.elapse(const Duration(seconds: 1));
        expect(changed.last, {LiveUpdates.anything});
        live.dispose();
      });
    });

    test('a failed connection is tried again after 1, 2, 5, 10 and 30 '
        'seconds, then every 30, each time with fresh sign-in headers', () {
      fakeAsync((async) {
        server.outcomes.addAll(List.filled(7, Exception('No network')));
        final live = liveUpdates()
          ..update(user: 'u1', household: 'h1', inFront: true);
        async.flushMicrotasks();
        expect(server.clients, hasLength(1));
        expect(live.status, LiveStatus.connecting);

        for (final (pause, tries) in [
          (1, 2),
          (2, 3),
          (5, 4),
          (10, 5),
          (30, 6),
          (30, 7),
        ]) {
          async.elapse(Duration(seconds: pause) - const Duration(seconds: 1));
          async.flushMicrotasks();
          expect(server.clients, hasLength(tries - 1), reason: '$pause s');
          async.elapse(const Duration(seconds: 1));
          expect(server.clients, hasLength(tries), reason: '$pause s');
        }
        expect(signIns, 7);
        expect(tokens(), [for (var i = 1; i <= 7; i++) 'Bearer token-$i']);
        expect(
          [for (final client in server.clients) client.closed],
          [for (var i = 0; i < 7; i++) true],
        );

        // The eighth opens: what was missed meanwhile is read again.
        async.elapse(const Duration(seconds: 30));
        expect(live.status, LiveStatus.live);
        expect(server.clients.last.headers?['Authorization'], 'Bearer token-8');
        expect(readAgain, [false]);
        live.dispose();
      });
    });

    test('opening that takes over 15 seconds counts as failed', () {
      fakeAsync((async) {
        server.gate = Completer<void>();
        final live = liveUpdates()
          ..update(user: 'u1', household: 'h1', inFront: true);
        async.elapse(const Duration(seconds: 14));
        expect(server.clients.single.closed, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(server.clients.single.closed, isTrue);
        server.gate = null;
        async.elapse(const Duration(seconds: 1));
        expect(server.clients, hasLength(2));
        expect(live.status, LiveStatus.live);
        live.dispose();
      });
    });

    test('a dropped connection opens again after a second, with a new '
        "token, and reads the household's screens again", () {
      fakeAsync((async) {
        final live = connected(async);

        server.clients.single.drop();
        async.flushMicrotasks();
        expect(live.status, LiveStatus.connecting);
        async.elapse(const Duration(milliseconds: 999));
        expect(server.clients, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));

        expect(server.clients, hasLength(2));
        expect(live.status, LiveStatus.live);
        expect(tokens(), ['Bearer token-1', 'Bearer token-2']);
        expect(readAgain, [false]);
        live.dispose();
      });
    });

    test('a connection that keeps dropping waits longer each time; one that '
        'held 30 seconds starts again from a second', () {
      fakeAsync((async) {
        final live = connected(async);

        for (final pause in [1, 2, 5]) {
          server.clients.last.drop();
          async.elapse(Duration(seconds: pause));
          expect(live.status, LiveStatus.live, reason: '$pause s');
        }
        expect(server.clients, hasLength(4));

        async.elapse(const Duration(seconds: 30));
        server.clients.last.drop();
        async.elapse(const Duration(seconds: 1));
        expect(server.clients, hasLength(5));
        expect(live.status, LiveStatus.live);
        live.dispose();
      });
    });

    test('another household on screen: a new connection names it, and '
        'nothing is read again (every screen loads afresh anyway)', () {
      fakeAsync((async) {
        final live = connected(async);

        live.update(user: 'u1', household: 'h2', inFront: true);
        async.flushMicrotasks();

        expect(server.clients.first.closed, isTrue);
        expect(server.clients.last.headers?['X-Household'], 'h2');
        expect(server.open, [server.clients.last]);
        expect(live.status, LiveStatus.live);
        expect(readAgain, isEmpty);

        // Until the household is known, it waits; Today is read meanwhile.
        live.update(user: 'u1', household: null, inFront: true);
        async.elapse(const Duration(seconds: 30));
        expect(server.open, isEmpty);
        expect(polls, 1);
        live.update(user: 'u1', household: 'h1', inFront: true);
        async.flushMicrotasks();
        expect(server.clients.last.headers?['X-Household'], 'h1');
        expect(live.status, LiveStatus.live);
        live.dispose();
      });
    });

    test('signing out closes it, and nothing is tried or read meanwhile', () {
      fakeAsync((async) {
        final live = connected(async);

        live.update(user: null, household: null, inFront: true);
        async.elapse(const Duration(minutes: 5));

        expect(server.clients.single.closed, isTrue);
        expect(server.clients, hasLength(1));
        expect(live.status, LiveStatus.off);
        expect(polls, 0);
        live.dispose();
      });
    });

    test('back within 30 seconds (the camera, the photo picker): the same '
        'connection, and nothing is read again; what it heard meanwhile is '
        'read as usual', () {
      fakeAsync((async) {
        final live = connected(async);

        live.update(user: 'u1', household: 'h1', inFront: false);
        async.elapse(const Duration(seconds: 10));
        server.change([LiveTopics.feeding]);
        async.elapse(const Duration(seconds: 19));
        expect(changed, [
          {LiveTopics.feeding},
        ]);
        live.update(user: 'u1', household: 'h1', inFront: true);
        async.elapse(const Duration(minutes: 5));

        expect(server.clients, hasLength(1));
        expect(server.open, [server.clients.single]);
        expect(live.status, LiveStatus.live);
        expect(readAgain, isEmpty);
        expect(polls, 0);
        live.dispose();
      });
    });

    test('away for 30 seconds it closes; back in front it opens again and '
        'reads everything but Today and the role, which their screens read '
        'themselves', () {
      fakeAsync((async) {
        final live = connected(async);

        live.update(user: 'u1', household: 'h1', inFront: false);
        async.elapse(LiveUpdates.awayGrace - const Duration(seconds: 1));
        expect(server.open, [server.clients.single]);
        async.elapse(const Duration(seconds: 1));
        expect(server.clients.single.closed, isTrue);
        expect(live.status, LiveStatus.off);
        async.elapse(const Duration(minutes: 5));
        expect(polls, 0);

        live.update(user: 'u1', household: 'h1', inFront: true);
        async.flushMicrotasks();
        expect(server.clients, hasLength(2));
        expect(live.status, LiveStatus.live);
        expect(readAgain, [true]);

        // Away again for long, and the first try back fails: by the time it
        // opens, Today and the role are behind too.
        live.update(user: 'u1', household: 'h1', inFront: false);
        async.elapse(LiveUpdates.awayGrace);
        server.outcomes.add(Exception('No network yet'));
        live.update(user: 'u1', household: 'h1', inFront: true);
        async.elapse(const Duration(seconds: 1));
        expect(live.status, LiveStatus.live);
        expect(readAgain, [true, false]);
        live.dispose();
      });
    });

    test('hidden while connecting and shown again within 30 seconds: the '
        'connection that was opening opens, the only one', () {
      fakeAsync((async) {
        server.gate = Completer<void>();
        final live = liveUpdates()
          ..update(user: 'u1', household: 'h1', inFront: true);
        async.elapse(const Duration(seconds: 3));
        live.update(user: 'u1', household: 'h1', inFront: false);
        async.elapse(const Duration(seconds: 5));
        live.update(user: 'u1', household: 'h1', inFront: true);
        server.gate!.complete();
        async.flushMicrotasks();

        expect(server.clients, hasLength(1));
        expect(live.status, LiveStatus.live);
        // The session's first connection: nothing to catch up on.
        expect(readAgain, isEmpty);
        live.dispose();
      });
    });

    test('hidden while connecting for longer: the tries stop after 30 '
        'seconds and late answers change nothing; shown again, a new '
        'connection opens and the screens are read again', () {
      fakeAsync((async) {
        server.gate = Completer<void>();
        final live = liveUpdates()
          ..update(user: 'u1', household: 'h1', inFront: true)
          ..update(user: 'u1', household: 'h1', inFront: false);
        // Meanwhile it goes on: the first try times out after 15 seconds,
        // the next one starts a second later.
        async.elapse(LiveUpdates.awayGrace);
        expect(live.status, LiveStatus.off);
        final tries = server.clients.length;
        expect(tries, 2);
        expect(
          [for (final client in server.clients) client.closed],
          [true, true],
        );

        server.gate!.complete();
        server.gate = null;
        async.elapse(const Duration(minutes: 1));
        expect(live.status, LiveStatus.off);
        expect(server.clients, hasLength(tries));
        expect(server.open, isEmpty);

        live.update(user: 'u1', household: 'h1', inFront: true);
        async.flushMicrotasks();
        expect(server.clients, hasLength(tries + 1));
        expect(server.open, [server.clients.last]);
        expect(live.status, LiveStatus.live);
        expect(readAgain, [true]);
        live.dispose();
      });
    });

    test('a refusal is not tried again until another household is on '
        'screen or the app comes back to the front', () {
      fakeAsync((async) {
        server.outcomes.add(_notAMember);
        final live = liveUpdates()
          ..update(user: 'u1', household: 'h1', inFront: true);
        async.elapse(const Duration(minutes: 10));

        expect(live.status, LiveStatus.refused);
        expect(server.clients, hasLength(1));
        // Without a connection Today is read every 30 seconds.
        expect(polls, 20);

        live.update(user: 'u1', household: 'h2', inFront: true);
        async.flushMicrotasks();
        expect(server.clients, hasLength(2));
        expect(live.status, LiveStatus.live);

        server.outcomes.add(_notAMember);
        live.update(user: 'u1', household: 'h1', inFront: true);
        async.elapse(const Duration(minutes: 1));
        expect(live.status, LiveStatus.refused);
        expect(server.clients, hasLength(3));

        // Back from a moment away: still refused.
        live.update(user: 'u1', household: 'h1', inFront: false);
        live.update(user: 'u1', household: 'h1', inFront: true);
        async.elapse(const Duration(minutes: 1));
        expect(server.clients, hasLength(3));
        expect(live.status, LiveStatus.refused);

        // Back after the connection would have closed: tried again.
        live.update(user: 'u1', household: 'h1', inFront: false);
        async.elapse(LiveUpdates.awayGrace);
        live.update(user: 'u1', household: 'h1', inFront: true);
        async.flushMicrotasks();
        expect(server.clients, hasLength(4));
        expect(live.status, LiveStatus.live);
        live.dispose();
      });
    });

    test('without a connection Today is read every 30 seconds; not while '
        'connected, nor in the background', () {
      fakeAsync((async) {
        server.outcomes.addAll(List.filled(5, Exception('No network')));
        final live = liveUpdates()
          ..update(user: 'u1', household: 'h1', inFront: true);
        async.elapse(const Duration(seconds: 29));
        expect(polls, 0);
        async.elapse(const Duration(seconds: 1));
        expect(polls, 1);

        // The sixth try, at 1 + 2 + 5 + 10 + 30 = 48 seconds, opens.
        async.elapse(const Duration(seconds: 30));
        expect(live.status, LiveStatus.live);
        expect(polls, 1);
        async.elapse(const Duration(minutes: 5));
        expect(polls, 1);

        server.clients.last.drop();
        server.outcomes.addAll(List.filled(10, Exception('No network')));
        async.elapse(const Duration(seconds: 60));
        expect(polls, 3);

        // Away: still read in the first 30 seconds (once more, at 450 s),
        // then not.
        async.elapse(const Duration(seconds: 10));
        live.update(user: 'u1', household: 'h1', inFront: false);
        async.elapse(const Duration(minutes: 5));
        expect(polls, 4);
        live.dispose();
      });
    });
  });

  group('what each topic reads again', () {
    test("the server's topics; Today with everything it shows", () {
      expect(
        liveTopicProviders.keys,
        unorderedEquals([
          LiveTopics.pets,
          LiveTopics.passport,
          LiveTopics.care,
          LiveTopics.weight,
          LiveTopics.feeding,
          LiveTopics.visits,
          LiveTopics.supplies,
          LiveTopics.documents,
          LiveTopics.imports,
          LiveTopics.household,
          LiveTopics.plan,
        ]),
      );
      expect(
        [
          for (final MapEntry(:key, :value) in liveTopicProviders.entries)
            if (value.contains(todayProvider)) key,
        ],
        unorderedEquals([
          LiveTopics.pets,
          LiveTopics.care,
          LiveTopics.feeding,
          LiveTopics.visits,
          LiveTopics.supplies,
          // Its time zone decides what "today" is.
          LiveTopics.household,
        ]),
      );
      // The household's: /me again, which re-checks the role.
      expect(liveTopicProviders[LiveTopics.household], contains(meProvider));
      // A visit that took place adds records and moves plans.
      expect(
        liveTopicProviders[LiveTopics.visits],
        containsAll([visitsProvider, carePlansProvider, careRecordsProvider]),
      );
      // A weighing changes the weight log only; a check-up's weight is in
      // it too, so a record changed (or a visit that took place) reads it
      // again.
      expect(liveTopicProviders[LiveTopics.weight], [weightLogProvider]);
      expect(liveTopicProviders[LiveTopics.care], contains(weightLogProvider));
      expect(
        liveTopicProviders[LiveTopics.visits],
        contains(weightLogProvider),
      );
      // A mark changes no estimate; a schedule changed also sends `supplies`,
      // which reads the estimates and the schedules.
      expect(
        liveTopicProviders[LiveTopics.feeding],
        isNot(contains(suppliesProvider)),
      );
      expect(
        liveTopicProviders[LiveTopics.supplies],
        containsAll([suppliesProvider, feedingSchedulesProvider]),
      );
      // AI photos used by a chip or package scan or the connection test.
      expect(
        liveTopicProviders[LiveTopics.plan],
        unorderedEquals([householdPlanProvider, aiStatusProvider]),
      );
    });

    test("the hub is at the API's origin, not under /api/v1", () {
      expect(
        liveUpdatesUrl('https://collarbell.example'),
        Uri.parse('https://collarbell.example/hubs/household'),
      );
    });
  });

  group('in the app', () {
    const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

    testWidgets('connects once the profile sync has created the user on '
        'the server, naming the household on screen', (tester) async {
      SharedPreferences.setMockInitialValues({
        DevAuthRepository.uidKey: testUid,
        DevAuthRepository.emailKey: 'dev@collarbell.local',
      });
      final live = FakeLiveServer();
      final me = _SlowSyncMe();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:5080',
              authMode: AuthMode.dev,
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          meRepositoryProvider.overrideWithValue(me),
          deviceTimeZoneProvider.overrideWithValue(() async => 'Europe/Berlin'),
          realtimeClientFactoryProvider.overrideWithValue(live.newClient),
        ],
      );
      container.listen(liveUpdatesProvider, (_, _) {});
      await tester.pump();
      expect(live.clients, isEmpty);

      me.gate.complete();
      await tester.pump();

      expect(live.open, hasLength(1));
      expect(live.open.single.headers, {
        'X-Dev-User': testUid,
        'X-Dev-Email': 'dev@collarbell.local',
        // The household the sync's answer named.
        'X-Household': FakeMeRepository.homeId,
        'X-Client': liveClientId,
      });
      expect(
        live.open.single.url,
        Uri.parse('http://localhost:5080/hubs/household'),
      );
      container.dispose();
      expect(live.open, isEmpty);
    });

    testWidgets("another phone's change reads Today again; the same change "
        "from this phone, or one Today doesn't show, doesn't", (tester) async {
      final live = FakeLiveServer();
      final today = FakeTodayRepository();
      await pumpApp(
        tester,
        location: AppRoutes.today,
        live: live,
        overrides: fakeRepositories(today: today),
      );
      final calls = today.calls;

      live.change([LiveTopics.feeding], origin: liveClientId);
      live.change([LiveTopics.documents]);
      await tester.pump(LiveUpdates.collectFor);
      await tester.pumpAndSettle();
      expect(today.calls, calls);

      live.change([LiveTopics.feeding]);
      live.change([LiveTopics.care, LiveTopics.feeding]);
      await tester.pump(LiveUpdates.collectFor);
      await tester.pumpAndSettle();
      expect(today.calls, calls + 1);
    });

    testWidgets("another phone's new pet shows in the list at once", (
      tester,
    ) async {
      final live = FakeLiveServer();
      final pets = FakePetsRepository();
      await pumpApp(
        tester,
        location: AppRoutes.pets,
        live: live,
        overrides: fakeRepositories(pets: pets),
      );
      expect(find.text('Murka'), findsNothing);

      pets.pets.add(murka);
      live.change([LiveTopics.pets]);
      await tester.pump(LiveUpdates.collectFor);
      await tester.pumpAndSettle();

      expect(find.text('Murka'), findsOneWidget);
    });

    testWidgets("another phone's weighing shows on the Weight tab at once", (
      tester,
    ) async {
      final live = FakeLiveServer();
      final weight = FakeWeightRepository();
      await pumpApp(
        tester,
        location: '/pets/p1?tab=weight',
        live: live,
        overrides: fakeRepositories(
          pets: FakePetsRepository([murka]),
          weight: weight,
        ),
      );
      expect(find.text('No weighings yet'), findsOneWidget);

      weight.weighings.add(testWeight('w1', on: testToday(), kg: 4.2));
      live.change([LiveTopics.weight]);
      await tester.pump(LiveUpdates.collectFor);
      await tester.pumpAndSettle();

      expect(find.text('4.2 kg'), findsWidgets);
    });

    testWidgets("the household's topic asks for the role again: a role an "
        'owner changed shows at once', (tester) async {
      final me = FakeMeRepository(
        households: [
          testHousehold(FakeMeRepository.homeId, role: HouseholdRole.member),
        ],
      );
      final live = FakeLiveServer();
      await pumpApp(tester, location: AppRoutes.pets, live: live, me: me);
      expect(find.text('Add pet'), findsOneWidget);

      me.households.first = testHousehold(
        FakeMeRepository.homeId,
        role: HouseholdRole.helper,
      );
      live.change([LiveTopics.household]);
      await tester.pump(LiveUpdates.collectFor);
      await tester.pumpAndSettle();

      expect(find.text('Add pet'), findsNothing);
    });

    testWidgets('a topic the app does not know reads everything again', (
      tester,
    ) async {
      final live = FakeLiveServer();
      final me = FakeMeRepository();
      final today = FakeTodayRepository();
      await pumpApp(
        tester,
        location: AppRoutes.today,
        live: live,
        me: me,
        overrides: fakeRepositories(today: today),
      );
      final (todayCalls, meCalls) = (today.calls, me.getCalls);

      live.change(['walks']);
      await tester.pump(LiveUpdates.collectFor);
      await tester.pumpAndSettle();

      expect(today.calls, todayCalls + 1);
      expect(me.getCalls, meCalls + 1);
    });

    testWidgets('back from the camera within 30 seconds: the same '
        'connection, and only Today is read again, by its own screen', (
      tester,
    ) async {
      final live = FakeLiveServer();
      final pets = FakePetsRepository();
      final today = FakeTodayRepository();
      // An empty Today shows the first steps, which watch the pets.
      await pumpApp(
        tester,
        location: AppRoutes.today,
        live: live,
        overrides: fakeRepositories(pets: pets, today: today),
      );
      final (petCalls, todayCalls) = (pets.calls, today.calls);

      _away(tester);
      await tester.pump(const Duration(seconds: 20));
      _back(tester);
      await tester.pumpAndSettle();

      expect(live.clients, hasLength(1));
      expect(live.open, [live.clients.single]);
      expect(pets.calls, petCalls);
      expect(today.calls, todayCalls + 1);
    });

    testWidgets('away for 30 seconds the connection closes; back in front it '
        "opens again and the household's screens are read again, Today "
        'once', (tester) async {
      final live = FakeLiveServer();
      final pets = FakePetsRepository();
      final today = FakeTodayRepository();
      await pumpApp(
        tester,
        location: AppRoutes.today,
        live: live,
        overrides: fakeRepositories(pets: pets, today: today),
      );
      final (petCalls, todayCalls) = (pets.calls, today.calls);

      _away(tester);
      await tester.pump(LiveUpdates.awayGrace);
      expect(live.clients.single.closed, isTrue);
      expect(live.open, isEmpty);

      // Back in front, with a slow network: Today reads itself again at
      // once (TodayScreen), the rest waits for the connection.
      live.gate = Completer<void>();
      _back(tester);
      await tester.pumpAndSettle();
      expect(live.clients, hasLength(2));
      expect(today.calls, todayCalls + 1);
      expect(pets.calls, petCalls);

      live.gate!.complete();
      await tester.pumpAndSettle();
      expect(live.open, [live.clients.last]);
      expect(pets.calls, petCalls + 1);
      // Not twice.
      expect(today.calls, todayCalls + 1);
    });

    testWidgets('another group on screen: the connection opens again for it; '
        'signing out closes it', (tester) async {
      final live = FakeLiveServer();
      await pumpApp(
        tester,
        location: AppRoutes.today,
        live: live,
        me: FakeMeRepository(
          households: [
            testHousehold(FakeMeRepository.homeId),
            testHousehold('office', name: 'Office'),
          ],
        ),
      );
      expect(live.open.single.headers?['X-Household'], FakeMeRepository.homeId);

      appContainer(tester)
          .read(currentHouseholdProvider.notifier)
          .switchTo(const CurrentHousehold(id: 'office', name: 'Office'));
      await tester.pumpAndSettle();
      expect(live.clients.first.closed, isTrue);
      expect(live.open.single.headers?['X-Household'], 'office');

      await appContainer(tester).read(authRepositoryProvider).signOut();
      await tester.pumpAndSettle();
      expect(live.open, isEmpty);
      expect(live.clients.last.closed, isTrue);
    });

    testWidgets('refused because the user is no longer in the group: no '
        'retries, Today read every 30 seconds', (tester) async {
      final live = FakeLiveServer()..outcomes.add(_notAMember);
      final today = FakeTodayRepository();
      await pumpApp(
        tester,
        location: AppRoutes.today,
        live: live,
        overrides: fakeRepositories(today: today),
      );
      final calls = today.calls;

      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      expect(live.clients, hasLength(1));
      expect(live.open, isEmpty);
      expect(
        appContainer(tester).read(liveUpdatesProvider).status,
        LiveStatus.refused,
      );
      expect(today.calls, calls + 2);
    });
  });
}
