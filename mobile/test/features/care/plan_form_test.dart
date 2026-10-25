// Adding a plan: the preset picker offers only what suits the pet's
// species, the form starts from the preset, and "last done" gives the next
// due date. Editing: pausing, deleting (history stays), server errors.
import 'dart:async';

import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/care_rules.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/care/plan_form_screen.dart';
import 'package:collarbell/features/care/widgets/kind_dropdown.dart';
import 'package:collarbell/features/care/widgets/plan_row.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);
const rex = Pet(id: 'p2', name: 'Rex', species: PetSpecies.dog);

Finder field(String label) => find.descendant(
  of: find.widgetWithText(CbTextField, label),
  matching: find.byType(TextFormField),
);

String textOf(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(field(label)).controller!.text;

ApiException validationError(Map<String, List<String>> errors) => ApiException(
  ApiErrorKind.validation,
  statusCode: 400,
  problem: ProblemDetails(status: 400, errors: errors),
);

String medium(DateTime date) => DateFormat.yMMMd('en').format(date);

void main() {
  late FakeCareRepository care;
  late FakePetsRepository pets;

  setUp(() {
    care = FakeCareRepository();
    pets = FakePetsRepository([murka, rex]);
  });

  Future<void> open(WidgetTester tester, String location) => pumpApp(
    tester,
    location: location,
    overrides: fakeRepositories(pets: pets, care: care),
  );

  testWidgets('the picker offers a cat only cat presets', (tester) async {
    await open(tester, '/pets/p1?tab=health');
    await tester.tap(find.text('Add plan'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a plan'), findsOneWidget);
    expect(care.presetRequests, [PetSpecies.cat]);
    expect(find.text('Own plan'), findsOneWidget);
    expect(find.text('Vaccinations'), findsOneWidget);
    expect(find.text('Rabies'), findsOneWidget);
    expect(find.text('Every year'), findsOneWidget);
    expect(
      find.text('When the risk is unknown: at least 4 times a year.'),
      findsOneWidget,
      reason: 'the note in the app language',
    );
    expect(find.text('K9 Advantix'), findsNothing);
    expect(find.text('Dogs only'), findsNothing);
  });

  testWidgets('a dog sees dog presets, the dog-only one with a warning', (
    tester,
  ) async {
    await open(tester, '/pets/p2/plans/presets');

    expect(care.presetRequests, [PetSpecies.dog]);
    expect(find.text('K9 Advantix'), findsOneWidget);
    expect(find.text('Dogs only'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Before travel'), 300);
    expect(find.text('Tapeworm treatment before travel'), findsOneWidget);
    expect(find.text('One-off'), findsOneWidget);
    expect(find.text('Deworming'), findsNothing, reason: 'cat presets');
  });

  testWidgets('a preset fills the form; "last done" gives the next date', (
    tester,
  ) async {
    await open(tester, '/pets/p1?tab=health');
    await tester.tap(find.text('Add plan'));
    await tester.pumpAndSettle();
    // The group is called "Deworming" too; the preset is below it.
    await tapVisible(tester, find.text('Deworming').last);

    expect(find.text('New plan'), findsOneWidget);
    expect(textOf(tester, 'What to do'), 'Deworming');
    expect(
      find.text('When the risk is unknown: at least 4 times a year.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '3',
      reason: 'every 3...',
    );
    expect(find.text('months'), findsOneWidget);
    // Without a last date, the plan is due today.
    final today = testToday();
    expect(find.text(medium(today)), findsOneWidget);

    // Done about three months ago: due again in a few days.
    final lastDone = DateTime(today.year, today.month - 3, today.day + 5);
    await pickDate(tester, 'Last done (optional)', lastDone);
    final nextDue = addInterval(
      lastDone,
      const CareInterval(3, IntervalUnit.month),
    );
    expect(find.text(medium(nextDue)), findsOneWidget);
    expect(
      find.text(
        'Counted from the last time and the interval. You can change it.',
      ),
      findsOneWidget,
    );

    // Another interval counts again from the same last date.
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.pumpAndSettle();
    final monthly = addInterval(
      lastDone,
      const CareInterval(1, IntervalUnit.month),
    );
    expect(find.text(medium(monthly)), findsOneWidget);
    expect(find.text('month'), findsOneWidget, reason: '1 month, singular');
    await tester.enterText(find.byType(TextFormField).at(1), '3');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final (petId, input) = care.createdPlans.single;
    expect(petId, 'p1');
    expect(input.kind, CareKind.deworming);
    expect(input.title, 'Deworming');
    expect(input.presetCode, 'cat-deworm');
    expect(input.interval, const CareInterval(3, IntervalUnit.month));
    expect(input.nextDueOn, nextDue);
    expect(input.active, isNull);
    // The picker closed too: back on the Health tab, with the new plan.
    expect(find.text('Choose a plan'), findsNothing);
    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.widgetWithText(PlanRow, 'Deworming'), findsOneWidget);
  });

  testWidgets('a vaccination preset offers the cat vaccine targets', (
    tester,
  ) async {
    await open(tester, '/pets/p1/plans/new?preset=cat-rabies');

    expect(textOf(tester, 'What to do'), 'Rabies');
    final rabies = find.widgetWithText(FilterChip, 'Rabies');
    await tester.ensureVisible(rabies);
    expect(tester.widget<FilterChip>(rabies).selected, isTrue);
    expect(
      find.widgetWithText(FilterChip, 'Panleukopenia (FPV)'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilterChip, 'Distemper (CDV)'), findsNothing);

    await tapVisible(
      tester,
      find.widgetWithText(FilterChip, 'Panleukopenia (FPV)'),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(care.createdPlans.single.$2.targets, [
      VaccineTarget.rabies,
      VaccineTarget.fpv,
    ]);
  });

  testWidgets('an own plan: the title is required; a one-off has a due date', (
    tester,
  ) async {
    await open(tester, '/pets/p1/plans/new');

    expect(textOf(tester, 'What to do'), isEmpty);
    expect(find.text('Last done (optional)'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter what needs to be done'), findsOneWidget);
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
    expect(care.createdPlans, isEmpty);

    await tester.enterText(field('What to do'), 'Ear cleaning');
    await tapVisible(tester, find.text('Once'));
    expect(find.text('Last done (optional)'), findsNothing);
    expect(find.text('Due on'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final input = care.createdPlans.single.$2;
    expect(input.title, 'Ear cleaning');
    expect(input.interval, isNull);
    expect(input.presetCode, isNull);
    expect(input.nextDueOn, testToday());
  });

  testWidgets('editing: pausing sends "active", other edits keep it', (
    tester,
  ) async {
    care.plans = [testPlan('plan1', daysLeft: 5, defaultProduct: 'Milbemax')];
    await open(tester, '/pets/p1/plans/plan1/edit');

    expect(find.text('Edit plan'), findsOneWidget);
    expect(find.text('Last done (optional)'), findsNothing);
    expect(textOf(tester, 'Usual product (optional)'), 'Milbemax');
    await tester.enterText(field('What to do'), 'Deworming tablets');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(care.updatedPlans.last.$2.active, isNull);
    expect(care.updatedPlans.last.$2.remindOffsetsDays, [7, 1, 0]);

    await open(tester, '/pets/p1/plans/plan1/edit');
    await tapVisible(tester, find.byType(Switch));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(care.updatedPlans.last.$2.active, isFalse);
  });

  testWidgets('deleting a plan says the history stays', (tester) async {
    care.plans = [testPlan('plan1', daysLeft: 5)];
    await open(tester, '/pets/p1?tab=health');
    await tester.tap(find.widgetWithText(PlanRow, 'Deworming'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete plan'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Records already made with it stay in the history. You can't undo "
        'this.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(care.deletedPlans, ['plan1']);
    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.byType(PlanRow), findsNothing);
  });

  testWidgets('a lost response when adding: the retry sends the same request '
      'id and the plan is added once', (tester) async {
    // Review probe "plan_save", first part.
    await open(tester, '/pets/p1/plans/new?preset=cat-deworm');

    care.loseNextCreatePlanResponse = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(care.createPlanRequestIds, hasLength(2));
    expect(care.createPlanRequestIds.toSet(), hasLength(1), reason: 'same id');
    expect(care.plans, hasLength(1));
    expect(find.text('New plan'), findsNothing, reason: 'the form closed');
  });

  testWidgets('a lost response when adding, then Back: the Health tab shows '
      'the plan', (tester) async {
    await open(tester, '/pets/p1?tab=health');
    await tester.tap(find.text('Add plan'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('cat-deworm')));

    care.loseNextCreatePlanResponse = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // The user gives up: back to the picker, back to the Health tab.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.widgetWithText(PlanRow, 'Deworming'), findsOneWidget);
  });

  testWidgets('a plan from a dog preset stays editable when the pet is a '
      'cat: the preset code goes back unchanged', (tester) async {
    // Review probe "plan_save", second part. The fix is the server's: it
    // checks the preset only when the code changes. This test keeps the
    // app's side of it: an edit sends the plan's code as it is.
    final strict = PresetCheckingCare(
      plans: [testPlan('plan1', daysLeft: 5, presetCode: 'dog-deworm')],
    );
    await pumpApp(
      tester,
      location: '/pets/p1/plans/plan1/edit',
      overrides: fakeRepositories(pets: pets, care: strict),
    );

    await tapVisible(tester, find.byType(Switch));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final input = strict.updatedPlans.single.$2;
    expect(input.presetCode, 'dog-deworm');
    expect(input.active, isFalse);
    expect(find.text('Edit plan'), findsNothing, reason: 'saved and closed');
  });

  testWidgets('no input while saving: the type menu does not open, and the '
      'form closes once saved', (tester) async {
    // Review probe "busy_dropdown".
    await open(tester, '/pets/p1/plans/new?preset=cat-deworm');

    care.savePlanGate = Completer<void>();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.tap(find.byType(KindDropdown), warnIfMissed: false);
    // The save bar spins: time is pumped instead of settling.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Vaccination'), findsNothing, reason: 'no menu');

    care.savePlanGate!.complete();
    care.savePlanGate = null;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PlanFormScreen), findsNothing);
    expect(care.plans, hasLength(1));
  });

  testWidgets('a plan deleted elsewhere: the form says so and closes', (
    tester,
  ) async {
    care.plans = [testPlan('plan1', daysLeft: 5)];
    await open(tester, '/pets/p1/plans/plan1/edit');

    // Another phone deletes the plan.
    care.plans.clear();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('This plan has been deleted, probably on another device.'),
      findsOneWidget,
    );
    expect(find.byType(PlanFormScreen), findsNothing);
  });

  testWidgets('a server error on a field shows under it', (tester) async {
    care.savePlanError = validationError({
      'title': ['Enter what needs to be done.'],
    });
    await open(tester, '/pets/p1/plans/new?preset=cat-deworm');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text("This value wasn't accepted. Check it."), findsOneWidget);
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
    expect(find.text('New plan'), findsOneWidget, reason: 'the form stays');
  });
}

/// Checks presets like the server: one of another species is refused, but
/// only when the plan's code changes.
class PresetCheckingCare extends FakeCareRepository {
  PresetCheckingCare({super.plans});

  @override
  Future<CarePlan> updatePlan(String id, CarePlanInput input) async {
    final old = await getPlan(id);
    final code = input.presetCode;
    if (code != old.presetCode && code != null && code.startsWith('dog-')) {
      throw validationError({
        'presetCode': ['This preset is for another species.'],
      });
    }
    return super.updatePlan(id, input);
  }
}
