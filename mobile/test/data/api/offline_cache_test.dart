// The offline copy of answers: kept for the screens' GET requests, given
// back only when the server can't be reached, per user and household; and
// the short wait for a server in the home network.
import 'dart:io';
import 'dart:typed_data';

import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/data/api/api_providers.dart';
import 'package:collarbell/data/api/household_header.dart';
import 'package:collarbell/data/api/local_network.dart';
import 'package:collarbell/data/api/offline_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_client_test.dart' show json;

/// Answers with [answer] while [up], or fails like a sleeping Mac.
class _Server implements HttpClientAdapter {
  _Server(this.answer);

  ResponseBody Function(RequestOptions options) answer;
  var up = true;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri.path}');
    if (!up) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'No route to host',
      );
    }
    return answer(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Server server;
  late MemoryOfflineCacheStore store;
  late List<ServerReachability> reports;
  late String? user;

  /// The household the requests name, as the app's interceptor does.
  late String? household;
  late DateTime now;
  late bool reachable;
  late bool serverBack;
  late Dio dio;

  setUp(() {
    server = _Server((_) => json({'pets': 1}, 200));
    store = MemoryOfflineCacheStore();
    reports = [];
    user = 'anna';
    household = 'home';
    now = DateTime(2026, 10, 2, 14, 5);
    reachable = true;
    serverBack = false;
    dio = Dio(BaseOptions(baseUrl: 'http://192.168.0.166:5080'))
      ..httpClientAdapter = server
      ..interceptors.add(
        HouseholdHeaderInterceptor(
          household: () => household,
          onNotAMember: (_) {},
          onRoleRefused: () {},
        ),
      )
      ..interceptors.add(
        OfflineCacheInterceptor(
          store: store,
          userKey: () => user,
          onReachability: reports.add,
          isReachable: () => reachable,
          clock: () => now,
        )..probe = () async => serverBack,
      );
  });

  test('the last answer comes back when the server is unreachable', () async {
    await dio.get<Object?>('/api/v1/pets');
    server.up = false;

    final response = await dio.get<Object?>('/api/v1/pets');

    expect(response.data, {'pets': 1});
    expect(
      response.extra[OfflineCacheInterceptor.cachedAtKey],
      DateTime(2026, 10, 2, 14, 5),
    );
    expect(reports, [
      const ServerReachability.reachable(),
      ServerReachability.unreachable(dataAt: DateTime(2026, 10, 2, 14, 5)),
    ]);
  });

  test('a live answer always wins over the copy', () async {
    await dio.get<Object?>('/api/v1/pets');
    server.answer = (_) => json({'pets': 2}, 200);

    final response = await dio.get<Object?>('/api/v1/pets');

    expect(response.data, {'pets': 2});
    expect(response.extra[OfflineCacheInterceptor.cachedAtKey], isNull);
  });

  test('no copy: the network error goes on, and the app knows', () async {
    server.up = false;

    await expectLater(
      dio.get<Object?>('/api/v1/pets'),
      throwsA(isA<DioException>()),
    );
    expect(reports, [const ServerReachability.unreachable()]);
  });

  test('an error status is an answer: no copy instead of it', () async {
    await dio.get<Object?>('/api/v1/pets');
    server.answer = (_) => json({'title': 'Boom'}, 500);

    await expectLater(
      dio.get<Object?>('/api/v1/pets'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.badResponse,
        ),
      ),
    );
    expect(reports.last, const ServerReachability.reachable());
  });

  test('copies are per user', () async {
    await dio.get<Object?>('/api/v1/pets');
    user = 'boris';
    server.up = false;

    await expectLater(
      dio.get<Object?>('/api/v1/pets'),
      throwsA(isA<DioException>()),
    );
  });

  test("copies are per household: one group's never show in another", () async {
    await dio.get<Object?>('/api/v1/pets');
    household = 'office';
    server.answer = (_) => json({'pets': 2}, 200);
    await dio.get<Object?>('/api/v1/pets');
    server.up = false;

    expect((await dio.get<Object?>('/api/v1/pets')).data, {'pets': 2});
    household = 'home';
    expect((await dio.get<Object?>('/api/v1/pets')).data, {'pets': 1});
    household = 'cottage';
    await expectLater(
      dio.get<Object?>('/api/v1/pets'),
      throwsA(isA<DioException>()),
    );
  });

  test('the key names the user and the household of the request', () {
    final interceptor = OfflineCacheInterceptor(
      store: store,
      userKey: () => 'anna',
      onReachability: (_) {},
      isReachable: () => true,
    );
    RequestOptions request(String? household) => RequestOptions(
      path: '/api/v1/pets',
      baseUrl: 'http://192.168.0.166:5080',
      headers: {householdHeader: ?household},
    );

    expect(interceptor.keyFor(request('home')), 'anna home /api/v1/pets?');
    expect(interceptor.keyFor(request('office')), 'anna office /api/v1/pets?');
    // Before the app knows its household: which one the server picks can
    // change, so nothing is kept.
    expect(interceptor.keyFor(request(null)), isNull);
  });

  test('changes, AI scans and files are never answered from a copy', () async {
    await dio.post<Object?>('/api/v1/pets', data: {'name': 'Murka'});
    await dio.get<Object?>('/api/v1/ai/status');
    await dio.get<Object?>('/api/v1/files/f1');
    expect(store.entries, isEmpty);

    server.up = false;
    await expectLater(
      dio.post<Object?>('/api/v1/pets', data: {'name': 'Murka'}),
      throwsA(isA<DioException>()),
    );
  });

  test(
    "Today's copy serves another date: it is still the best there is",
    () async {
      await dio.get<Object?>(
        '/api/v1/today',
        queryParameters: {'date': '2026-10-02'},
      );
      server.up = false;

      final response = await dio.get<Object?>(
        '/api/v1/today',
        queryParameters: {'date': '2026-10-03'},
      );

      expect(response.data, {'pets': 1});
    },
  );

  test('other lists keep a copy per query', () async {
    await dio.get<Object?>(
      '/api/v1/pets',
      queryParameters: {'includeArchived': 'true'},
    );
    server.up = false;

    await expectLater(
      dio.get<Object?>('/api/v1/pets'),
      throwsA(isA<DioException>()),
    );
  });

  group('copies on the phone', () {
    late Directory folder;

    setUp(() {
      folder = Directory.systemTemp.createTempSync('offline_cache_test');
      addTearDown(() => folder.deleteSync(recursive: true));
    });

    FileOfflineCacheStore fileStore() =>
        FileOfflineCacheStore(() async => Directory('${folder.path}/copies'));

    test(
      'those kept before households were in the key are dropped, once',
      () async {
        final copies = Directory('${folder.path}/copies')..createSync();
        final old = File('${copies.path}/0123456789abcdef.json')
          ..writeAsStringSync('{"at": "2026-10-01T10:00:00Z", "body": 1}');

        final first = fileStore();
        expect(await first.read('anna home /api/v1/pets?'), isNull);
        expect(old.existsSync(), isFalse);
        await first.write(
          'anna home /api/v1/pets?',
          CachedAnswer(1, DateTime.utc(2026, 10, 5)),
        );

        // The next start keeps what was kept since.
        final next = fileStore();
        expect((await next.read('anna home /api/v1/pets?'))?.body, 1);
      },
    );

    test("a left household's copies go, the others stay", () async {
      final store = fileStore();
      final at = DateTime.utc(2026, 10, 5);
      await store.write('anna home /api/v1/pets?', CachedAnswer(1, at));
      await store.write('anna office /api/v1/pets?', CachedAnswer(2, at));
      await store.write('anna office /api/v1/today?', CachedAnswer(3, at));

      await store.clearWhere(
        (key) => key.startsWith(
          OfflineCacheInterceptor.householdKeyPrefix('anna', 'office'),
        ),
      );

      expect((await store.read('anna home /api/v1/pets?'))?.body, 1);
      expect(await store.read('anna office /api/v1/pets?'), isNull);
      expect(await store.read('anna office /api/v1/today?'), isNull);
    });
  });

  test('the copy survives as JSON', () {
    final answer = CachedAnswer({
      'items': [1, 2],
    }, DateTime.utc(2026, 10, 2, 12, 5));

    final back = CachedAnswer.fromJson(answer.toJson())!;

    expect(back.body, {
      'items': [1, 2],
    });
    expect(back.at, DateTime.utc(2026, 10, 2, 12, 5).toLocal());
    expect(CachedAnswer.fromJson('garbage'), isNull);
  });

  group('a server in the local network (development)', () {
    test('local and private addresses', () {
      for (final host in [
        'localhost',
        '127.0.0.1',
        '10.0.2.2',
        '192.168.0.166',
        '172.20.1.5',
        '100.101.102.103',
        'macbook.local',
      ]) {
        expect(isLocalNetworkHost(host), isTrue, reason: host);
      }
      for (final host in [
        'api.collarbell.app',
        '8.8.8.8',
        '172.32.0.1',
        '100.128.0.1',
        '192.169.0.1',
        '',
      ]) {
        expect(isLocalNetworkHost(host), isFalse, reason: host);
      }
    });

    test('it gets 3 seconds to answer, others 10', () {
      expect(
        ApiClient.connectTimeoutFor('http://192.168.0.166:5080'),
        const Duration(seconds: 3),
      );
      expect(
        ApiClient.connectTimeoutFor('https://api.collarbell.app'),
        const Duration(seconds: 10),
      );
    });
  });

  group('changes are never made on top of copies', () {
    test('no answer from the server: a change is not sent', () async {
      reachable = false;

      await expectLater(
        dio.post<Object?>('/api/v1/routines/r1/marks', data: {}),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<ChangeWhileOffline>(),
          ),
        ),
      );
      expect(server.requests, isEmpty);
    });

    test(
      'the server is back: still not sent, the screens reload first',
      () async {
        reachable = false;
        serverBack = true;

        await expectLater(
          dio.post<Object?>('/api/v1/routines/r1/marks', data: {}),
          throwsA(
            isA<DioException>().having(
              (e) => e.error,
              'error',
              isA<ScreensRefreshed>(),
            ),
          ),
        );
        expect(server.requests, isEmpty);
      },
    );

    test('right after a change, a copy from before it is not shown', () async {
      await dio.get<Object?>('/api/v1/pets');
      now = now.add(const Duration(seconds: 5));
      await dio.post<Object?>('/api/v1/pets', data: {'name': 'Murka'});
      server.up = false;

      // The screens reload to show the change: an error, not the old list.
      now = now.add(const Duration(seconds: 5));
      await expectLater(
        dio.get<Object?>('/api/v1/pets'),
        throwsA(isA<DioException>()),
      );

      // Later the copy is fine again: the banner says how old it is.
      now = now.add(const Duration(minutes: 2));
      final response = await dio.get<Object?>('/api/v1/pets');
      expect(response.data, {'pets': 1});
    });

    test("the app's reports to the visor pass by: no change, sent while "
        'copies may show, and they tell the app nothing', () async {
      await dio.get<Object?>('/api/v1/pets');
      reports.clear();
      now = now.add(const Duration(seconds: 5));
      await dio.post<Object?>('/api/v1/events', data: {'events': []});
      expect(reports, isEmpty);

      // Not a change: the copy from before it still shows.
      server.up = false;
      now = now.add(const Duration(seconds: 5));
      expect((await dio.get<Object?>('/api/v1/pets')).data, {'pets': 1});

      // While the screens may show copies, a report still goes to the
      // server (a change would not), and when it fails, no banner says so.
      reachable = false;
      reports.clear();
      await expectLater(
        dio.post<Object?>('/api/v1/events', data: {'events': []}),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionError,
          ),
        ),
      );
      expect(server.requests.last, 'POST /api/v1/events');
      expect(reports, isEmpty);
    });
  });

  test('an answer that comes after a sign-out is not kept', () async {
    server.answer = (_) {
      user = null;
      return json({'pets': 1}, 200);
    };

    await dio.get<Object?>('/api/v1/pets');
    await Future<void>.delayed(Duration.zero);

    expect(store.entries, isEmpty);
  });

  test("a pet's AI scans are not kept", () async {
    await dio.get<Object?>('/api/v1/pets/p1/ai-imports');
    await dio.get<Object?>('/api/v1/ai-imports/s1');

    expect(store.entries, isEmpty);
  });

  test('the data export and what deleting the account would do are not '
      'kept; the profile is', () async {
    await dio.get<Object?>('/api/v1/me/export');
    await dio.get<Object?>('/api/v1/me/deletion');
    await Future<void>.delayed(Duration.zero);
    expect(store.entries, isEmpty);

    await dio.get<Object?>('/api/v1/me');
    await Future<void>.delayed(Duration.zero);
    expect(store.entries.keys, ['anna home /api/v1/me?']);
  });

  test('the banner keeps the oldest copy time while there is no answer', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reachability = container.read(serverReachabilityProvider.notifier);
    ServerReachability state() => container.read(serverReachabilityProvider);

    reachability.report(
      ServerReachability.unreachable(dataAt: DateTime(2026, 10, 1, 21, 0)),
    );
    reachability.report(
      ServerReachability.unreachable(dataAt: DateTime(2026, 10, 2, 8, 0)),
    );
    reachability.report(const ServerReachability.unreachable());
    expect(state().dataAt, DateTime(2026, 10, 1, 21, 0));

    reachability.report(const ServerReachability.reachable());
    expect(state().reachable, isTrue);
    reachability.report(
      ServerReachability.unreachable(dataAt: DateTime(2026, 10, 2, 9, 0)),
    );
    expect(state().dataAt, DateTime(2026, 10, 2, 9, 0));
  });
}
