// Roles: a helper sees everything but only marks — fed, "Done", bought — so
// the buttons that add, change or delete are not there; a member has them.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/features/feeding/feeding.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/supplies/supply.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

FakeMeRepository asRole(HouseholdRole role) => FakeMeRepository(
  households: [testHousehold(FakeMeRepository.homeId, role: role)],
);

TodayFeeding feeding(String routineId, String petName, {FeedingMark? mark}) =>
    TodayFeeding(
      routineId: routineId,
      petId: 'pet-$petName',
      petName: petName,
      time: const TimeOfDay(hour: 8, minute: 0),
      mark: mark,
    );

FeedingMark markBy(String routineId, {required bool byMe}) => FeedingMark(
  id: 'mark-$routineId',
  routineId: routineId,
  date: testToday(),
  time: const TimeOfDay(hour: 8, minute: 0),
  skipped: false,
  doneAt: DateTime(2026, 10, 2, 8, 2),
  byMe: byMe,
  byName: byMe ? null : 'Boris',
);

void main() {
  testWidgets('a helper adds no pets and changes none, but sees them', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.pets,
      me: asRole(HouseholdRole.helper),
      overrides: fakeRepositories(pets: FakePetsRepository([murka])),
    );

    expect(find.text('Murka'), findsOneWidget);
    expect(find.text('Add pet'), findsNothing);

    await tester.tap(find.text('Murka'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit details'), findsNothing);
    expect(find.byTooltip('More actions'), findsNothing);
    expect(find.text('Add photo'), findsNothing);

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    expect(find.text('Microchips and tattoos'), findsOneWidget);
    expect(find.text('Add pages'), findsNothing);
    expect(find.text('Add'), findsNothing);
    expect(find.text('No passport details yet.'), findsOneWidget);
  });

  testWidgets('a helper marks a plan done, as it is: no new plans, records, '
      'photos or another next date', (tester) async {
    final care = FakeCareRepository(plans: [testPlan('pl1')]);
    await pumpApp(
      tester,
      location: '/pets/p1?tab=health',
      me: asRole(HouseholdRole.helper),
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        care: care,
      ),
    );

    expect(find.text('Deworming'), findsOneWidget);
    expect(find.text('Add plan'), findsNothing);
    expect(find.text('Add past record'), findsNothing);
    expect(find.text('No records yet.'), findsOneWidget);
    // The plan's form doesn't open.
    await tester.tap(find.text('Deworming'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);

    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as done'), findsOneWidget);
    expect(find.text('Add photos'), findsNothing);
    // The next date as worked out: no other can be picked (a member can,
    // see below).
    expect(find.text('Change'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(care.completions.single.$1, 'pl1');
  });

  testWidgets("a helper sees the feeding schedules but can't change them", (
    tester,
  ) async {
    final feeding = FakeFeedingRepository();
    await feeding.createSchedule(
      'p1',
      const FeedingInput(
        times: [TimeOfDay(hour: 8, minute: 0)],
        days: everyDay,
      ),
      requestId: 'r',
    );
    await pumpApp(
      tester,
      location: '/pets/p1?tab=feeding',
      me: asRole(HouseholdRole.helper),
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        feeding: feeding,
      ),
    );

    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);
    await tester.tap(find.text('8:00 AM'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('a helper marks feedings, and takes back only their own '
      'marks', (tester) async {
    final marks = FakeFeedingRepository();
    await pumpApp(
      tester,
      location: AppRoutes.today,
      me: asRole(HouseholdRole.helper),
      overrides: fakeRepositories(
        feeding: marks,
        today: FakeTodayRepository(
          feedingMarks: marks,
          feedings: [
            feeding('r1', 'Barsik'),
            feeding('r2', 'Murka', mark: markBy('r2', byMe: false)),
            feeding('r3', 'Rex', mark: markBy('r3', byMe: true)),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('fed-r1@480')));
    await tester.pumpAndSettle();
    expect(marks.marks.map((mark) => mark.$1), ['r1']);

    // Boris's mark: no way to take it back.
    await tester.tap(find.byKey(const ValueKey('marked-r2@480')));
    await tester.pumpAndSettle();
    expect(find.text('Murka: take the mark back?'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('marked-r3@480')));
    await tester.pumpAndSettle();
    expect(find.text('Rex: take the mark back?'), findsOneWidget);
    await tester.tap(find.text('Take back'));
    await tester.pumpAndSettle();
    expect(marks.undone, ['mark-r3']);
  });

  testWidgets('a helper marks purchases but adds no supplies, and takes '
      'back only their own', (tester) async {
    final supplies = FakeSuppliesRepository(
      supplies: [testSupply('s1', 'Royal Canin')],
    );
    supplies.stock['s1'] = [
      StockEntry(
        id: 'mine',
        kind: StockEventKind.purchase,
        quantity: 2000,
        at: DateTime(2026, 10, 1),
        byMe: true,
      ),
      StockEntry(
        id: 'boris',
        kind: StockEventKind.purchase,
        quantity: 2000,
        at: DateTime(2026, 9, 20),
        byMe: false,
        byName: 'Boris',
      ),
    ];
    await pumpApp(
      tester,
      location: AppRoutes.supplies,
      me: asRole(HouseholdRole.helper),
      overrides: fakeRepositories(supplies: supplies),
    );

    expect(find.byKey(const ValueKey('addSupply')), findsNothing);
    await tester.tap(find.text('Royal Canin'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bought')), findsOneWidget);
    expect(find.byTooltip('More actions'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('entry-boris')),
      300,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('entry-mine')),
        matching: find.byTooltip('Take back'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('entry-boris')),
        matching: find.byTooltip('Take back'),
      ),
      findsNothing,
    );
  });

  testWidgets('a member has the buttons to add and change', (tester) async {
    final care = FakeCareRepository(plans: [testPlan('pl1')]);
    await pumpApp(
      tester,
      location: '/pets/p1?tab=health',
      me: asRole(HouseholdRole.member),
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        care: care,
      ),
    );

    expect(find.byTooltip('Edit details'), findsOneWidget);
    expect(find.text('Add plan'), findsOneWidget);
    expect(find.text('Add past record'), findsOneWidget);

    // "Done" with photos and another next date.
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Add photos'), findsOneWidget);
    final next = testToday().add(const Duration(days: 40));
    await tapVisible(tester, find.text('Change'));
    await enterPickerDate(tester, next);
    await tapVisible(tester, find.text('Save'));
    expect(care.completions.single.$2.nextDueOn, next);

    // The Pets tab again: its list.
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    expect(find.text('Add pet'), findsOneWidget);
  });
}
