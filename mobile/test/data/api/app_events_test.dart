// The visor's reporter (data/api/app_events.dart). It sends what waits after
// 30 seconds, at once when 20 wait (and when the app goes to the
// background, see test/app/visor_test.dart), at most 50 a request and 5
// requests a minute, keeps at most 200, and tries a failed batch once more.
// Only for a signed-in person. A report is a pattern, a fixed name, an
// error's kind and codes or a crash's type and lines of the app: never the
// person's words. The app sends them to POST /api/v1/events.
import 'dart:async';

import 'package:collarbell/app/app_config.dart';
import 'package:collarbell/app/preferences.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/data/api/api_providers.dart';
import 'package:collarbell/data/api/app_events.dart';
import 'package:collarbell/data/api/app_session.dart';
import 'package:collarbell/data/api/offline_cache.dart';
import 'package:collarbell/features/auth/auth_providers.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:dio/dio.dart' show RequestOptions, ResponseBody;
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client_test.dart' show FakeAdapter, json;

final _start = DateTime.utc(2026, 10, 5, 12);

List<String> _names(Iterable<AppEvent> events) => [
  for (final event in events) event.name,
];

/// A crash's trace as the Dart VM writes it, through the app and Flutter.
final _trace = StackTrace.fromString('''
#0      Pet.fromJson (package:collarbell/features/pets/pet.dart:140:7)
#1      _MapStream._handleData (dart:async/stream_pipe.dart:213:31)
#2      PetsScreen.build (package:collarbell/features/pets/pets_screen.dart:42:9)
#3      StatelessElement.build (package:flutter/src/widgets/framework.dart:5799:49)
<asynchronous suspension>
#4      ApiPetsRepository.getPets (package:collarbell/features/pets/pets_repository.dart:70:5)
#5      HomeShell.build (package:collarbell/app/home_shell.dart:117:12)
#6      ProviderElement.watch (package:riverpod/src/core/element.dart:301:5)
#7      CollarbellApp.build (package:collarbell/app/app.dart:50:12)
#8      runCollarbell (package:collarbell/main.dart:46:3)
''');

void main() {
  group('the reporter', () {
    late List<List<AppEvent>> sent;
    late String? user;

    /// When set, sending throws it.
    late Object? failure;

    AppEventReporter reporter(
      FakeAsync async, {
      Future<void> Function(List<AppEvent> events)? send,
    }) => AppEventReporter(
      send:
          send ??
          (events) async {
            if (failure case final error?) throw error;
            sent.add(events);
          },
      user: () => user,
      clock: async.getClock(_start).now,
    );

    setUp(() {
      sent = [];
      user = 'u1';
      failure = null;
    });

    test('waits 30 seconds after the first report, then sends what waits', () {
      fakeAsync((async) {
        final visor = reporter(async);

        visor.screen('/today');
        async.elapse(const Duration(seconds: 10));
        visor.action(AppAction.fed);
        async.elapse(const Duration(seconds: 19));
        expect(sent, isEmpty);
        async.elapse(const Duration(seconds: 1));

        expect(sent, hasLength(1));
        expect(_names(sent.single), ['/today', 'fed']);
        expect(sent.single.first.at, _start);
        expect(sent.single.last.at, _start.add(const Duration(seconds: 10)));
        // Nothing waits: nothing more goes.
        async.elapse(const Duration(minutes: 5));
        expect(sent, hasLength(1));
        visor.dispose();
      });
    });

    test('sends at once when 20 wait', () {
      fakeAsync((async) {
        final visor = reporter(async);

        for (var i = 0; i < 19; i++) {
          visor.screen('/s$i');
        }
        async.flushMicrotasks();
        expect(sent, isEmpty);
        visor.screen('/s19');
        async.flushMicrotasks();

        expect(sent.single, hasLength(20));
        expect(visor.waiting, isEmpty);
        visor.dispose();
      });
    });

    test('sends at most 50 a request, and keeps at most 200: a new report '
        'pushes the oldest out', () {
      fakeAsync((async) {
        final server = Completer<void>();
        var first = true;
        final visor = reporter(
          async,
          send: (events) async {
            // The first request takes its time.
            if (first) {
              first = false;
              await server.future;
            }
            sent.add(events);
          },
        );

        for (var i = 0; i < 20; i++) {
          visor.screen('/s$i');
        }
        async.flushMicrotasks();
        for (var i = 20; i < 250; i++) {
          visor.screen('/s$i');
        }
        expect(visor.waiting, hasLength(200));
        expect(visor.waiting.first.name, '/s50');
        server.complete();
        async.flushMicrotasks();

        expect([for (final batch in sent) batch.length], [20, 50, 50, 50, 50]);
        expect(sent[1].first.name, '/s50');
        expect(sent.last.last.name, '/s249');
        visor.dispose();
      });
    });

    test("a batch the server didn't take goes once more with the next one, "
        'then is dropped', () {
      fakeAsync((async) {
        final visor = reporter(async);
        failure = const ApiException(ApiErrorKind.network);

        visor.screen('/today');
        async.elapse(const Duration(seconds: 30));
        expect(_names(visor.waiting), ['/today']);
        visor.screen('/pets');
        async.elapse(const Duration(seconds: 30));
        // Twice failed: gone. The newer one gets its second chance.
        expect(_names(visor.waiting), ['/pets']);
        failure = null;
        async.elapse(const Duration(seconds: 30));

        expect(sent.map(_names), [
          ['/pets'],
        ]);
        visor.dispose();
      });
    });

    test('a burst waits: at most 5 requests a minute (the server takes 6)', () {
      fakeAsync((async) {
        final visor = reporter(async);

        for (var i = 0; i < 400; i++) {
          visor.screen('/s$i');
          async.flushMicrotasks();
        }
        expect(sent, hasLength(5));
        expect(visor.waiting, hasLength(200));
        async.elapse(const Duration(seconds: 59));
        expect(sent, hasLength(5));
        async.elapse(const Duration(seconds: 1));

        expect(sent, hasLength(9));
        expect(sent.last.last.name, '/s399');
        visor.dispose();
      });
    });

    test('keeps nothing before sign-in', () {
      fakeAsync((async) {
        user = null;
        final visor = reporter(async);

        visor.screen('/sign-in');
        visor.errorShown(const ApiException(ApiErrorKind.network));
        visor.crash(StateError('boom'), _trace);
        expect(visor.waiting, isEmpty);
        user = 'u1';
        visor.userChanged();
        visor.screen('/today');
        async.elapse(const Duration(seconds: 30));

        expect(sent.map(_names), [
          ['/today'],
        ]);
        visor.dispose();
      });
    });

    test('a sign-out drops what waits, unsent, and a batch on its way is not '
        'put back', () {
      fakeAsync((async) {
        final server = Completer<void>();
        var requests = 0;
        final visor = reporter(
          async,
          send: (events) async {
            requests++;
            await server.future;
            throw const ApiException(ApiErrorKind.unauthorized);
          },
        );

        for (var i = 0; i < 20; i++) {
          visor.screen('/s$i');
        }
        async.flushMicrotasks();
        visor.action(AppAction.done);
        user = null;
        visor.userChanged();
        expect(visor.waiting, isEmpty);
        server.complete();
        async.flushMicrotasks();
        expect(visor.waiting, isEmpty);
        // Someone else signs in: nothing of the one before goes.
        user = 'u2';
        async.elapse(const Duration(minutes: 2));

        expect(requests, 1);
        expect(visor.waiting, isEmpty);
        visor.dispose();
      });
    });

    test('another person signing in drops what waits for the one before', () {
      fakeAsync((async) {
        final visor = reporter(async);

        visor.screen('/today');
        user = 'u2';
        visor.screen('/pets');
        async.elapse(const Duration(seconds: 30));

        expect(sent.map(_names), [
          ['/pets'],
        ]);
        visor.dispose();
      });
    });

    test('a screen is told once while it stays', () {
      fakeAsync((async) {
        final visor = reporter(async);

        visor.screen('/pets');
        // The same screen with another query, e.g. ?tab=health.
        visor.screen('/pets');
        visor.screen('/pets/:petId');
        visor.screen('/pets');

        expect(_names(visor.waiting), ['/pets', '/pets/:petId', '/pets']);
        expect(visor.waiting.map((event) => event.kind), [
          AppEventKind.screen,
          AppEventKind.screen,
          AppEventKind.screen,
        ]);
        visor.dispose();
      });
    });

    test('an action goes by its fixed name', () {
      fakeAsync((async) {
        final visor = reporter(async);

        for (final action in AppAction.values) {
          visor.action(action);
        }

        expect(_names(visor.waiting), [
          'fed',
          'fed-all',
          'done',
          'visit-took-place',
          'bought',
          'pet-saved',
          'scan-started',
          'note-started',
          'invite-created',
          'joined-group',
          'group-switched',
        ]);
        expect(
          visor.waiting.every((event) => event.kind == AppEventKind.action),
          isTrue,
        );
        visor.dispose();
      });
    });

    test("an error: its kind, status, problem type and trace id, never the "
        "server's words; each error once, however often its screen builds", () {
      fakeAsync((async) {
        final visor = reporter(async);
        const refused = ApiException(
          ApiErrorKind.forbidden,
          statusCode: 403,
          problem: ProblemDetails(
            type: ProblemTypes.roleForbidden,
            title: "Anna can't change Murka",
            detail: 'Murka belongs to the household Home',
            traceId: '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
          ),
          message: "Anna can't change Murka",
        );

        visor.errorShown(refused);
        visor.errorShown(refused);
        visor.errorShown(
          ApiException(
            ApiErrorKind.network,
            message: 'Failed host lookup: collarbell.example',
            cause: StateError('Murka'),
          ),
        );
        visor.errorShown(StateError('Murka'));
        // Not a failed request, and not told apart from an equal one.
        visor.errorShown('Murka');

        expect(
          [for (final event in visor.waiting) (event.name, event.detail)],
          [
            (
              'forbidden',
              'status=403 type=urn:collarbell:problem:role-forbidden '
                  'traceId=00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
            ),
            ('network', null),
            ('unknown', 'type=StateError'),
          ],
        );
        expect(
          visor.waiting.every((event) => event.kind == AppEventKind.error),
          isTrue,
        );
        expect('${visor.waiting}', isNot(contains('Murka')));
        expect('${visor.waiting}', isNot(contains('Anna')));
        visor.dispose();
      });
    });

    test("a crash: its type and the app's lines it went through, never its "
        'message; the same crash once a minute', () {
      fakeAsync((async) {
        final visor = reporter(async);
        Object crash() => StateError('Murka has the chip 276098100123456');

        visor.crash(crash(), _trace);
        // A broken widget fails on every frame.
        visor.crash(crash(), _trace);
        async.elapse(const Duration(seconds: 59));
        visor.crash(crash(), _trace);
        visor.crash(ArgumentError('Murka'), null);
        async.elapse(const Duration(seconds: 1));
        visor.crash(crash(), _trace);
        async.elapse(const Duration(seconds: 30));

        final told = [for (final batch in sent) ...batch];
        expect(
          [for (final event in told) (event.name, event.detail)],
          [
            (
              'StateError',
              'features/pets/pet.dart:140 < features/pets/pets_screen.dart:42 '
                  '< features/pets/pets_repository.dart:70 '
                  '< app/home_shell.dart:117 < app/app.dart:50',
            ),
            ('ArgumentError', null),
            (
              'StateError',
              'features/pets/pet.dart:140 < features/pets/pets_screen.dart:42 '
                  '< features/pets/pets_repository.dart:70 '
                  '< app/home_shell.dart:117 < app/app.dart:50',
            ),
          ],
        );
        expect(told.every((event) => event.kind == AppEventKind.crash), isTrue);
        expect('$told', isNot(contains('Murka')));
        expect('$told', isNot(contains('2760981')));
        visor.dispose();
      });
    });

    test('names and details go without control characters, cut to what the '
        'server keeps', () {
      fakeAsync((async) {
        final visor = reporter(async);

        visor.screen('/a\u0000\nb${'x' * 200}');
        visor.errorShown(
          ApiException(
            ApiErrorKind.server,
            statusCode: 500,
            problem: ProblemDetails(type: 'urn:\r\n${'t' * 600}'),
          ),
        );

        final [screen, error] = visor.waiting;
        expect(screen.name, '/ab${'x' * 97}');
        expect(error.detail, hasLength(500));
        expect(error.detail, startsWith('status=500 type=urn:ttt'));
        visor.dispose();
      });
    });
  });

  group('lines of the app in a crash', () {
    test('only the app\'s, at most five, from a short trace too', () {
      expect(appFrames(null), isNull);
      expect(
        appFrames(
          StackTrace.fromString(
            '#0 Element.rebuild (package:flutter/src/widgets/framework.dart:1)',
          ),
        ),
        isNull,
      );
      // As package:stack_trace writes it.
      expect(
        appFrames(
          StackTrace.fromString(
            'package:collarbell/features/care/done_screen.dart 292:23  '
            '_DoneScreenState._save\n'
            'package:flutter/src/material/ink_well.dart 1182:21  '
            '_InkResponseState.handleTap\n',
          ),
        ),
        'features/care/done_screen.dart:292',
      );
    });
  });

  group('the app', () {
    late ProviderContainer container;
    late FakeAdapter adapter;
    late ResponseBody Function(RequestOptions options) answer;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
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
          appEventsOnProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      answer = (_) => json(null, 204);
      adapter = FakeAdapter((options) async => answer(options));
      container.read(apiClientProvider).dio.httpClientAdapter = adapter;
    });

    test('is off in debug builds, and so in tests, unless turned on', () {
      final plain = ProviderContainer();
      addTearDown(plain.dispose);

      // Tests run as debug builds.
      expect(plain.read(appEventsOnProvider), isFalse);
      expect(plain.read(appEventsProvider), isA<NoAppEvents>());
      expect(container.read(appEventsProvider), isA<AppEventReporter>());
    });

    test('sends the reports to POST /api/v1/events with the launch, the '
        'version and the moment in milliseconds', () async {
      final visor = container.read(appEventsProvider) as AppEventReporter;
      final before = DateTime.now().millisecondsSinceEpoch;

      visor.screen('/pets/:petId');
      visor.action(AppAction.petSaved);
      visor.errorShown(
        const ApiException(
          ApiErrorKind.server,
          statusCode: 500,
          problem: ProblemDetails(traceId: '00-abc-01'),
        ),
      );
      await visor.flush();

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.toString(), 'http://api.test/api/v1/events');
      expect(request.headers[appSessionHeader], appSession);
      expect(request.headers[appVersionHeader], appVersion);
      final body = request.data as Map<String, Object?>;
      expect(body['session'], appSession);
      expect(body['appVersion'], appVersion);
      final events = [
        for (final event in body['events']! as List<Object?>)
          event! as Map<String, Object?>,
      ];
      expect(
        [for (final event in events) (event['kind'], event['name'])],
        [
          ('Screen', '/pets/:petId'),
          ('Action', 'pet-saved'),
          ('Error', 'server'),
        ],
      );
      expect(events.last['detail'], 'status=500 traceId=00-abc-01');
      final at = events.first['atUnixMs']! as int;
      expect(
        at,
        inInclusiveRange(before, DateTime.now().millisecondsSinceEpoch),
      );
    });

    test('a sign-out drops what waits', () async {
      final visor = container.read(appEventsProvider) as AppEventReporter;
      visor.screen('/today');

      await container.read(authRepositoryProvider).signOut();
      await Future<void>.delayed(Duration.zero);

      expect(visor.waiting, isEmpty);
      await visor.flush();
      expect(adapter.requests, isEmpty);
    });

    test("crashes go to the visor, and the handlers that were there still get "
        'them', () {
      final flutterBefore = FlutterError.onError;
      final platformBefore = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = flutterBefore;
        PlatformDispatcher.instance.onError = platformBefore;
      });
      final presented = <FlutterErrorDetails>[];
      FlutterError.onError = presented.add;
      final uncaught = <Object>[];
      PlatformDispatcher.instance.onError = (error, stack) {
        uncaught.add(error);
        return true;
      };
      final visor = container.read(appEventsProvider) as AppEventReporter;

      watchCrashes();
      // Once is enough: a second start changes nothing.
      watchCrashes();
      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('Murka'), stack: _trace),
      );
      // Expected ones, e.g. a photo that didn't load, stay out.
      FlutterError.onError!(
        FlutterErrorDetails(exception: Exception('photo'), silent: true),
      );
      final handled = PlatformDispatcher.instance.onError!(
        ArgumentError('Murka'),
        StackTrace.fromString('#0 main (package:collarbell/main.dart:16:3)'),
      );

      expect(presented, hasLength(2));
      expect(uncaught, hasLength(1));
      expect(handled, isTrue);
      expect(
        [for (final event in visor.waiting) (event.kind, event.name)],
        [
          (AppEventKind.crash, 'StateError'),
          (AppEventKind.crash, 'ArgumentError'),
        ],
      );
      expect(visor.waiting.last.detail, 'main.dart:16');
    });
  });
}
