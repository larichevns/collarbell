// Visits: the form (what it needs, what it sends) and "The visit took
// place" with the suggested plan.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/visits/visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

Pet testPet(String id, String name) =>
    Pet(id: id, name: name, species: PetSpecies.cat, sex: PetSex.unknown);

void main() {
  testWidgets('a visit needs a date, a time and a pet', (tester) async {
    final visits = FakeVisitsRepository();
    await pumpApp(
      tester,
      location: AppRoutes.newVisit,
      overrides: fakeRepositories(
        visits: visits,
        pets: FakePetsRepository([
          testPet('p1', 'Murka'),
          testPet('p2', 'Barsik'),
        ]),
      ),
    );

    await tapVisible(tester, find.text('Save'));

    expect(find.text('Choose the time'), findsOneWidget);
    expect(find.text('Choose at least one pet'), findsOneWidget);
    expect(visits.lastInput, isNull);
  });

  testWidgets('a new visit: the kind names it, reminders a day and two hours '
      'before', (tester) async {
    final visits = FakeVisitsRepository();
    await pumpApp(
      tester,
      location: AppRoutes.newVisit,
      overrides: fakeRepositories(
        visits: visits,
        pets: FakePetsRepository([
          testPet('p1', 'Murka'),
          testPet('p2', 'Barsik'),
        ]),
      ),
    );
    final day = testToday().add(const Duration(days: 3));

    await pickDate(tester, 'Date', day);
    await tapVisible(
      tester,
      find
          .descendant(
            of: find.byKey(const ValueKey('time')),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await enterPickerTime(tester, const TimeOfDay(hour: 10, minute: 30));
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Barsik'));
    await tapVisible(tester, find.text('Save'));

    final input = visits.lastInput!;
    expect((input.type, input.title), (VisitType.vet, 'Vet'));
    expect(
      (input.date, input.time),
      (day, const TimeOfDay(hour: 10, minute: 30)),
    );
    expect(input.petIds, ['p2']);
    expect(input.remindMinutesBefore, [1440, 120]);
  });

  testWidgets('an edit that fails offline keeps what was typed', (
    tester,
  ) async {
    final visits = FakeVisitsRepository(
      visits: [
        Visit(
          id: 'v1',
          type: VisitType.vet,
          title: 'Vaccination',
          date: testToday().add(const Duration(days: 3)),
          time: const TimeOfDay(hour: 10, minute: 30),
          petIds: const ['p1'],
          remindMinutesBefore: const [1440, 120],
          status: VisitStatus.planned,
          durationMinutes: 45,
        ),
      ],
    );
    await pumpApp(
      tester,
      location: AppRoutes.editVisit('v1'),
      overrides: fakeRepositories(
        visits: visits,
        pets: FakePetsRepository([testPet('p1', 'Murka')]),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vaccination'),
      'Rabies shot',
    );
    visits.error = networkError;
    await tapVisible(tester, find.text('Save'));

    expect(find.text('Rabies shot'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    // Back online: the duration set elsewhere goes back as it was.
    visits.error = null;
    await tapVisible(tester, find.text('Save'));
    expect(visits.lastInput?.title, 'Rabies shot');
    expect(visits.lastInput?.durationMinutes, 45);
  });

  testWidgets('the visit took place: a record for each pet, and "Done" for '
      'the only plan of that kind that repeats', (tester) async {
    final yesterday = testToday().subtract(const Duration(days: 1));
    final visits = FakeVisitsRepository(
      visits: [
        Visit(
          id: 'v1',
          type: VisitType.vet,
          title: 'Check-up',
          date: yesterday,
          time: const TimeOfDay(hour: 10, minute: 30),
          petIds: const ['p1'],
          remindMinutesBefore: const [1440, 120],
          status: VisitStatus.planned,
        ),
      ],
    );
    final care = FakeCareRepository(
      plans: [
        testPlan(
          'plan-exam',
          kind: CareKind.vetExam,
          title: 'Yearly check-up',
          interval: const CareInterval(1, IntervalUnit.year),
        ),
      ],
    );
    await pumpApp(
      tester,
      location: AppRoutes.visit('v1'),
      overrides: fakeRepositories(
        visits: visits,
        care: care,
        pets: FakePetsRepository([testPet('p1', 'Murka')]),
      ),
    );

    await tester.tap(find.text('The visit took place'));
    await tester.pumpAndSettle();
    expect(find.text('Mark "Yearly check-up" done'), findsOneWidget);
    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('plan-plan-exam')),
    );
    expect(checkbox.value, isTrue);
    await tester.tap(find.text('The visit took place').last);
    await tester.pumpAndSettle();

    final (visitId, kind, planIds) = visits.completions.single;
    expect((visitId, kind), ('v1', CareKind.vetExam));
    expect(planIds, ['plan-exam']);
  });
}
