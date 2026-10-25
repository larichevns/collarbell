// The strip above the tabs while the server can't be reached: how old the
// copies on screen are, and "Try again" asks the server; once it answers,
// every screen reloads and the strip goes away.
import 'package:collarbell/app/home_shell.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/data/api/api_providers.dart';
import 'package:collarbell/data/api/offline_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/api/api_client_test.dart' show FakeAdapter, json;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

void main() {
  testWidgets('no answer: the age of the copies; Try again finds the server '
      'back, and the screens reload', (tester) async {
    final today = FakeTodayRepository();
    var serverUp = false;
    final health = FakeAdapter(
      (options) async => serverUp ? json('Healthy', 200) : json('', 503),
    );
    await pumpApp(
      tester,
      location: AppRoutes.today,
      overrides: [
        ...fakeRepositories(today: today),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: 'http://localhost:5080',
            authHeaders: () async => const {},
            httpClientAdapter: health,
            offlineCache: OfflineCacheInterceptor(
              store: MemoryOfflineCacheStore(),
              userKey: () => null,
              onReachability: ref
                  .read(serverReachabilityProvider.notifier)
                  .report,
              isReachable: () => ref.read(serverReachabilityProvider).reachable,
            ),
          ),
        ),
      ],
    );
    expect(find.textContaining('No connection'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeShell)),
    );
    container
        .read(serverReachabilityProvider.notifier)
        .report(
          ServerReachability.unreachable(
            dataAt: DateTime.now().copyWith(hour: 14, minute: 5),
          ),
        );
    await tester.pump();
    expect(
      find.text('No connection to the server · data from 14:05'),
      findsOneWidget,
    );

    // Still down: the strip stays.
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No connection'), findsOneWidget);

    // Back: the strip goes, and the screens load again with live data.
    serverUp = true;
    final calls = today.calls;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No connection'), findsNothing);
    expect(today.calls, greaterThan(calls));
  });

  testWidgets('nothing from the copy: the strip only says there is no '
      'connection', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.today,
      overrides: fakeRepositories(),
      language: 'ru',
    );
    ProviderScope.containerOf(tester.element(find.byType(HomeShell)))
        .read(serverReachabilityProvider.notifier)
        .report(const ServerReachability.unreachable());
    await tester.pump();

    expect(find.text('Нет связи с сервером'), findsOneWidget);
  });
}
