// Today: due care of all pets in three groups, a tap opens the pet's Health
// tab, "Done" works from here, and the list reloads after any care change.
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/app/router.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/done_screen.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/care/record_form_screen.dart';
import 'package:collarbell/features/feeding/feeding_form_screen.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pet_detail_screen.dart';
import 'package:collarbell/features/pets/pet_form_screen.dart';
import 'package:collarbell/features/today/today.dart';
import 'package:collarbell/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);
const rex = Pet(id: 'p2', name: 'Rex', species: PetSpecies.dog);
const archived = Pet(
  id: 'p3',
  name: 'Old Tom',
  species: PetSpecies.cat,
  status: PetStatus.archived,
);

TodayCareItem item(String planId, CareStatus status, int daysLeft) =>
    TodayCareItem(
      planId: planId,
      petId: 'p1',
      petName: 'Murka',
      kind: CareKind.deworming,
      title: planId,
      nextDueOn: DateTime(2026, 10, 1 + daysLeft),
      status: status,
      daysLeft: daysLeft,
    );

void main() {
  test('groupTodayItems: overdue, due soon, later; order kept', () {
    final groups = groupTodayItems([
      item('a', CareStatus.overdue, -5),
      item('b', CareStatus.overdue, -1),
      item('c', CareStatus.dueSoon, 2),
      item('d', CareStatus.upcoming, 20),
    ]);
    expect(groups.keys, [
      TodayGroup.overdue,
      TodayGroup.dueSoon,
      TodayGroup.later,
    ]);
    expect([for (final i in groups[TodayGroup.overdue]!) i.planId], ['a', 'b']);
    expect(groupTodayItems([item('c', CareStatus.dueSoon, 2)]).keys, [
      TodayGroup.dueSoon,
    ]);
  });

  late FakeCareRepository care;
  late FakePetsRepository pets;
  late FakeTodayRepository today;

  setUp(() {
    care = FakeCareRepository(
      plans: [
        testPlan(
          'rabies',
          kind: CareKind.vaccination,
          title: 'Rabies',
          interval: const CareInterval(1, IntervalUnit.year),
          daysLeft: -3,
        ),
        testPlan('deworm', petId: 'p2', daysLeft: 4),
        testPlan(
          'fleas',
          kind: CareKind.fleaTick,
          title: 'Fleas and ticks',
          interval: const CareInterval(1, IntervalUnit.month),
          daysLeft: 25,
        ),
        // Not on Today: too far away, paused, or of an archived pet.
        testPlan('exam', title: 'Check-up', daysLeft: 120),
        testPlan('paused', title: 'Paused plan', daysLeft: 2, active: false),
        testPlan('tom', petId: 'p3', title: 'Old Tom plan', daysLeft: 2),
      ],
    );
    pets = FakePetsRepository([murka, rex, archived]);
    today = FakeTodayRepository(care: care, pets: pets);
  });

  Future<void> openToday(WidgetTester tester) => pumpApp(
    tester,
    location: '/today',
    overrides: fakeRepositories(pets: pets, care: care, today: today),
  );

  testWidgets('due care of all pets, in three groups', (tester) async {
    await openToday(tester);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Overdue'), lessThan(top('Due soon')));
    expect(top('Due soon'), lessThan(top('Later')));
    expect(top('Rabies'), lessThan(top('Due soon')));
    expect(top('Deworming'), lessThan(top('Later')));
    expect(top('Later'), lessThan(top('Fleas and ticks')));

    // Each item: the pet and the kind (unless the title says it), then
    // when it is due.
    expect(find.text('Murka · Vaccination'), findsOneWidget);
    expect(find.text('Rex'), findsOneWidget);
    expect(find.textContaining('3 days overdue'), findsOneWidget);
    expect(find.textContaining('In 4 days'), findsOneWidget);
    expect(find.byTooltip('Done'), findsNWidgets(3));

    for (final hidden in ['Check-up', 'Paused plan', 'Old Tom plan']) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
  });

  testWidgets('a tap opens the pet on its Health tab', (tester) async {
    await openToday(tester);

    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();

    expect(find.text('Rex'), findsWidgets);
    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.text('Care plan'), findsOneWidget);
    expect(care.planListCalls, greaterThan(0));
  });

  testWidgets('every tap opens the Health tab, whatever tab the pet showed '
      'before', (tester) async {
    // Review probe "nav".
    await openToday(tester);
    await tester.tap(find.text('Rabies'));
    await tester.pumpAndSettle();
    expect(find.byType(HealthTab), findsOneWidget);

    // The user looks at the passport, then goes back to Today with the
    // bottom bar and taps the same item.
    await tester.tap(find.widgetWithText(Tab, 'Passport'));
    await tester.pumpAndSettle();
    expect(find.byType(PassportTab), findsOneWidget);
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rabies'));
    await tester.pumpAndSettle();

    final tabs = DefaultTabController.of(tester.element(find.byType(TabBar)));
    expect(tabs.index, PetTab.health.index);
    expect(find.byType(HealthTab), findsOneWidget);
  });

  testWidgets('a pet opened from Today keeps a form that is open in the Pets '
      'tab; Back returns to Today', (tester) async {
    // Review probe "nav_form".
    await pumpApp(
      tester,
      location: '/pets/p1/records/new',
      overrides: fakeRepositories(pets: pets, care: care, today: today),
    );
    const typed = 'Typed from the paper passport';
    await tester.enterText(find.byType(TextFormField).at(1), typed);

    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rabies'));
    await tester.pumpAndSettle();
    expect(find.byType(HealthTab), findsOneWidget);
    // The bottom bar stays, on Today.
    expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen).hitTestable(), findsOneWidget);

    // The form waits in the Pets tab, with what was typed.
    await tester.tap(find.text('Pets').last);
    await tester.pumpAndSettle();
    expect(find.byType(RecordFormScreen), findsOneWidget);
    expect(find.text(typed), findsOneWidget);
  });

  testWidgets('"Done" from Today; the item leaves Today', (tester) async {
    await openToday(tester);
    final calls = today.calls;

    // The second "Done": Rex's deworming, due soon.
    await tester.tap(find.byTooltip('Done').at(1));
    await tester.pumpAndSettle();
    expect(find.byType(DoneScreen), findsOneWidget);
    expect(find.text('Rex · Every 3 months'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(care.completions.single.$1, 'deworm');
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(today.calls, greaterThan(calls), reason: 'Today reloaded');
    expect(find.text('Deworming'), findsNothing);
    expect(find.text('Due soon'), findsNothing);
    expect(find.text('Rabies'), findsOneWidget);
  });

  testWidgets('an empty Today; pull to refresh', (tester) async {
    care.plans = [];
    await openToday(tester);

    expect(find.text('Nothing scheduled yet'), findsOneWidget);
    expect(
      find.text(
        'Feeding times, visits, and vaccinations and treatments due in the '
        'next 30 days will appear here.',
      ),
      findsOneWidget,
    );

    care.plans = [testPlan('deworm', daysLeft: 1)];
    await tester.fling(
      find.text('Nothing scheduled yet'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Deworming'), findsOneWidget);
    expect(find.textContaining('Tomorrow'), findsOneWidget);
  });

  testWidgets('a failed load shows the error with "Try again"', (tester) async {
    today.error = const ApiException(ApiErrorKind.network);
    await openToday(tester);

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    today.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Rabies'), findsOneWidget);
  });

  group('an empty Today says what to set up first', () {
    testWidgets('no pets: start with one', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.today,
        overrides: fakeRepositories(),
      );

      expect(find.text('Start with a pet'), findsOneWidget);
      await tester.tap(find.text('Add pet'));
      await tester.pumpAndSettle();

      expect(find.byType(PetFormScreen), findsOneWidget);
    });

    testWidgets("one pet: straight to its feeding and its care plan", (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: AppRoutes.today,
        overrides: fakeRepositories(
          pets: FakePetsRepository([murka, archived]),
        ),
      );
      expect(find.text('Nothing scheduled yet'), findsOneWidget);

      await tester.tap(find.text('Add feeding'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedingFormScreen), findsOneWidget);
      expect(appRouter(tester).state.uri.path, AppRoutes.newFeeding('p1'));

      appRouter(tester).go(AppRoutes.today);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vaccinations and treatments'));
      await tester.pumpAndSettle();
      expect(appRouter(tester).state.uri.path, AppRoutes.carePresets('p1'));
    });

    testWidgets('several pets: the list, to pick one', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.today,
        overrides: fakeRepositories(pets: FakePetsRepository([murka, rex])),
      );

      await tester.tap(find.text('Add feeding'));
      await tester.pumpAndSettle();

      expect(appRouter(tester).state.uri.path, AppRoutes.pets);
    });
  });
}
