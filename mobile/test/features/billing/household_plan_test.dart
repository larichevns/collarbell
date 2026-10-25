// The plan screen («Тариф»): the group's plan and until when, this month's
// AI photos with a bar and the day they count from zero again, what Premium
// gives, and that nothing can be bought here. More and the group screen show
// the plan and open it. The plan is the group's: another group, another one.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/features/billing/billing_repository.dart';
import 'package:collarbell/features/billing/household_plan.dart';
import 'package:collarbell/features/household/current_household.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/api/api_client_test.dart' show FakeAdapter, json;
import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

void main() {
  Future<void> openPlan(
    WidgetTester tester, {
    HouseholdPlan? plan,
    String language = 'en',
  }) => pumpApp(
    tester,
    location: AppRoutes.householdPlan,
    language: language,
    overrides: fakeRepositories(billing: FakeBillingRepository(plan: plan)),
  );

  LinearProgressIndicator bar(WidgetTester tester) =>
      tester.widget(find.byType(LinearProgressIndicator));

  testWidgets('Free: 7 of 20 AI photos with a bar, the day they count from '
      'zero again, what Premium gives, and nothing to buy', (tester) async {
    await openPlan(tester);

    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('The plan of “My home”'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('7 of 20'), findsOneWidget);
    expect(bar(tester).value, closeTo(0.35, 1e-9));
    expect(find.text('The count starts again on November 1.'), findsOneWidget);
    expect(find.text('What Premium gives'), findsOneWidget);
    expect(find.text('Up to 300 AI photos a month'), findsOneWidget);
    expect(
      find.text(
        'There are no payments in the app yet: for now, Premium is given by '
        'hand.',
      ),
      findsOneWidget,
    );
    // Nothing to buy, and no way out to buy elsewhere.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('This month\'s AI photos are used up.'), findsNothing);
  });

  testWidgets('Premium until a day: the day it ends, and no Premium section', (
    tester,
  ) async {
    await openPlan(
      tester,
      plan: testHouseholdPlan(
        kind: PlanKind.premium,
        expiresAt: DateTime(2026, 12, 31, 23, 59),
        aiPhotosUsed: 42,
      ),
    );

    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Until December 31, 2026'), findsOneWidget);
    expect(find.text('42 of 300'), findsOneWidget);
    expect(find.text('What Premium gives'), findsNothing);
  });

  testWidgets('Premium without an end', (tester) async {
    await openPlan(tester, plan: testHouseholdPlan(kind: PlanKind.premium));

    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('No end date'), findsOneWidget);
    expect(find.text('7 of 300'), findsOneWidget);
  });

  testWidgets('the month\'s photos used up: said, with what still works, and '
      'the bar is full', (tester) async {
    await openPlan(tester, plan: testHouseholdPlan(aiPhotosUsed: 20));

    expect(find.text('20 of 20'), findsOneWidget);
    expect(
      find.text(
        "This month's AI photos are used up. Typing things in and scanning "
        'barcodes work as before.',
      ),
      findsOneWidget,
    );
    expect(bar(tester).value, 1);
    expect(find.text('The count starts again on November 1.'), findsOneWidget);
  });

  testWidgets('in Russian: the dates as written in Russian', (tester) async {
    await openPlan(
      tester,
      language: 'ru',
      plan: testHouseholdPlan(
        kind: PlanKind.premium,
        expiresAt: DateTime(2026, 12, 31),
      ),
    );

    expect(find.text('Тариф'), findsOneWidget);
    expect(find.text('Тариф группы «Мой дом»'), findsOneWidget);
    expect(find.text('До 31 декабря 2026 г.'), findsOneWidget);
    expect(find.text('7 из 300'), findsOneWidget);
    expect(find.text('Счётчик обнулится 1 ноября.'), findsOneWidget);
    expect(
      find.text(
        'Оплаты в приложении пока нет: Premium сейчас выдаётся вручную.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('More shows the plan of the group, and opens it', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.more,
      overrides: fakeRepositories(
        billing: FakeBillingRepository(
          plan: testHouseholdPlan(kind: PlanKind.premium),
        ),
      ),
    );
    final row = find.byKey(const ValueKey('householdPlan'));

    await tester.scrollUntilVisible(row, 200);
    expect(
      find.descendant(of: row, matching: find.text('Plan')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Premium')),
      findsOneWidget,
    );
    await tapVisible(tester, row);
    expect(find.text('No end date'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
  });

  testWidgets("the group screen shows the plan and this month's photos, and "
      'opens it', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.household,
      overrides: fakeRepositories(),
    );
    final row = find.byKey(const ValueKey('plan'));

    await tester.scrollUntilVisible(row, 200);
    expect(
      find.descendant(of: row, matching: find.text('Free')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text('AI photos this month: 7 of 20'),
      ),
      findsOneWidget,
    );
    await tapVisible(tester, row);
    expect(find.text('7 of 20'), findsOneWidget);
  });

  testWidgets('another group, another plan: More shows the plan of the group '
      'on screen', (tester) async {
    final me = FakeMeRepository(
      households: [
        testHousehold(FakeMeRepository.homeId),
        testHousehold('office', name: 'Office', role: HouseholdRole.member),
      ],
    );
    final billing = FakeBillingRepository(
      byHousehold: {'office': testHouseholdPlan(kind: PlanKind.premium)},
    );
    await pumpApp(
      tester,
      location: AppRoutes.more,
      me: me,
      overrides: fakeRepositories(billing: billing),
    );
    // Like the X-Household header: the group the requests name.
    billing.household = () =>
        appContainer(tester).read(currentHouseholdProvider)?.id;
    final row = find.byKey(const ValueKey('householdPlan'));
    expect(
      find.descendant(of: row, matching: find.text('Free')),
      findsOneWidget,
    );

    await tapVisible(tester, find.byKey(const ValueKey('switchHousehold')));
    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: row, matching: find.text('Premium')),
      findsOneWidget,
    );
  });

  test('the API: the plan, and the days Premium ends and the count starts '
      'again on this phone', () async {
    final adapter = FakeAdapter(
      (_) async => json({
        'plan': 'Premium',
        'source': 'Manual',
        'expiresAt': '2026-12-31T12:00:00+00:00',
        'aiPhotosPerMonth': 300,
        'aiPhotosUsed': 12,
        'resetsAt': '2026-11-01T00:00:00+00:00',
        'premiumAiPhotosPerMonth': 300,
      }, 200),
    );
    final repository = ApiBillingRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        authHeaders: () async => {'X-Dev-User': 'dev-1'},
        httpClientAdapter: adapter,
      ),
    );

    final plan = await repository.getPlan();

    expect(adapter.requests.single.uri.path, '/api/v1/plan');
    expect(plan.kind, PlanKind.premium);
    expect(plan.expiresAt, DateTime.utc(2026, 12, 31, 12).toLocal());
    expect(plan.expiresAt!.isUtc, isFalse);
    expect(plan.resetsAt, DateTime.utc(2026, 11, 1).toLocal());
    expect(plan.resetsAt.isUtc, isFalse);
    expect(plan.aiPhotosPerMonth, 300);
    expect(plan.aiPhotosUsed, 12);
    expect(plan.premiumAiPhotosPerMonth, 300);
  });
}
