// The tabs with Home first: where the app opens, where links without a
// screen go, the five tabs in order, and tapped pushes still opening their
// own screens.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/features/home/home_screen.dart';
import 'package:collarbell/features/today/today_screen.dart';
import 'package:collarbell/features/visits/visit_detail_screen.dart';
import 'package:collarbell/features/visits/visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/pump.dart';

void main() {
  testWidgets('"/" and links without a screen go to Home', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.more,
      overrides: fakeRepositories(),
    );

    appRouter(tester).go('/');
    await tester.pumpAndSettle();
    expect(appRouter(tester).state.matchedLocation, AppRoutes.home);
    expect(find.byType(HomeScreen), findsOneWidget);

    appRouter(tester).go(AppRoutes.more);
    await tester.pumpAndSettle();
    appRouter(tester).go('/no/such/screen');
    await tester.pumpAndSettle();
    expect(appRouter(tester).state.matchedLocation, AppRoutes.home);
  });

  testWidgets('five tabs: Home, Today, Pets, Supplies, More', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.home,
      overrides: fakeRepositories(),
    );

    final labels = [
      for (final destination in tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      ))
        destination.label,
    ];
    expect(labels, ['Home', 'Today', 'Pets', 'Supplies', 'More']);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppRoutes.homeBranch,
    );

    for (final (label, location) in [
      ('Today', AppRoutes.today),
      ('Pets', AppRoutes.pets),
      ('Supplies', AppRoutes.supplies),
      ('More', AppRoutes.more),
      ('Home', AppRoutes.home),
    ]) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(appRouter(tester).state.matchedLocation, location, reason: label);
    }
  });

  testWidgets('a tapped push opens its own screen from Home: a feeding '
      'Today, a visit the visit on top of Today', (tester) async {
    final push = FakePushPlatform();
    final visits = FakeVisitsRepository(
      visits: [
        Visit(
          id: 'v1',
          type: VisitType.vet,
          title: 'Check-up',
          date: testToday().add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 10, minute: 0),
          petIds: const [],
          remindMinutesBefore: const [],
          status: VisitStatus.planned,
        ),
      ],
    );
    await pumpApp(
      tester,
      location: AppRoutes.home,
      overrides: fakeRepositories(push: push, visits: visits),
    );

    push.tap({'kind': 'feeding'});
    await tester.pumpAndSettle();
    expect(appRouter(tester).state.matchedLocation, AppRoutes.today);
    expect(find.byType(TodayScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    push.tap({'kind': 'appointment', 'appointmentId': 'v1'});
    await tester.pumpAndSettle();
    expect(find.byType(VisitDetailScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen).hitTestable(), findsOneWidget);
  });

  testWidgets('a push tapped while Home has a Today screen on top (the visit '
      'form) still opens Today, and a visit push the visit on Today', (
    tester,
  ) async {
    // Review probe: Home pushes `/today/visits/new`, so the location says
    // "inside Today" while the Home tab is on screen.
    final push = FakePushPlatform();
    final visits = FakeVisitsRepository(
      visits: [
        Visit(
          id: 'v1',
          type: VisitType.vet,
          title: 'Check-up',
          date: testToday().add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 10, minute: 0),
          petIds: const [],
          remindMinutesBefore: const [],
          status: VisitStatus.planned,
        ),
      ],
    );
    await pumpApp(
      tester,
      location: AppRoutes.home,
      overrides: fakeRepositories(push: push, visits: visits),
    );
    appRouter(tester).push(AppRoutes.newVisit);
    await tester.pumpAndSettle();
    expect(find.text('New visit'), findsOneWidget);

    push.tap({'kind': 'feeding'});
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppRoutes.todayBranch,
    );
    expect(find.byType(TodayScreen).hitTestable(), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    // The visit form waits on Home as it was left.
    expect(find.text('New visit'), findsOneWidget);
    push.tap({'kind': 'appointment', 'appointmentId': 'v1'});
    await tester.pumpAndSettle();
    expect(find.byType(VisitDetailScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppRoutes.todayBranch,
    );
  });
}
