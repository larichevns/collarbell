// "Done": the next date shown before saving (worked out like the server),
// the fields of each kind, and the safety rules: photos upload first,
// "Done" is sent once, photos are attached one by one afterwards, a retry
// reuses what went through, and the lists refresh even when the screen is
// gone.
import 'dart:async';

import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/care_rules.dart';
import 'package:collarbell/features/care/done_screen.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/shared/widgets/cb_date_field.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

Finder field(String label) => find.descendant(
  of: find.widgetWithText(CbTextField, label),
  matching: find.byType(TextFormField),
);

String medium(DateTime date) => DateFormat.yMMMd('en').format(date);

ApiException validationError(Map<String, List<String>> errors) => ApiException(
  ApiErrorKind.validation,
  statusCode: 400,
  problem: ProblemDetails(status: 400, errors: errors),
);

void main() {
  late FakeCareRepository care;
  late FakePetsRepository pets;
  late FakeFilesRepository files;
  late FakeMediaPicker picker;
  late FakeTodayRepository today;

  setUp(() {
    care = FakeCareRepository();
    pets = FakePetsRepository([murka]);
    files = FakeFilesRepository();
    picker = FakeMediaPicker()
      ..library = const [
        PickedMedia(path: '/tmp/a.jpg', name: 'a.jpg'),
        PickedMedia(path: '/tmp/b.jpg', name: 'b.jpg'),
      ];
    today = FakeTodayRepository(care: care, pets: pets);
  });

  Future<void> open(WidgetTester tester, String location) => pumpApp(
    tester,
    location: location,
    overrides: fakeRepositories(
      pets: pets,
      care: care,
      files: files,
      picker: picker,
      today: today,
    ),
  );

  Future<void> addPhotosFromLibrary(WidgetTester tester) async {
    await tapVisible(tester, find.text('Add photos'));
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
  }

  testWidgets('from the Health tab: the next date, then the plan moves', (
    tester,
  ) async {
    care.plans = [testPlan('plan1', daysLeft: 5, defaultProduct: 'Milbemax')];
    await open(tester, '/pets/p1?tab=health');
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(DoneScreen), findsOneWidget);
    expect(find.text('Mark as done'), findsOneWidget);
    expect(find.text('Murka · Every 3 months'), findsOneWidget);
    // The product of the plan, ready to change.
    expect(
      tester.widget<TextFormField>(field('Product')).controller!.text,
      'Milbemax',
    );
    // Deworming has no time and no "valid until".
    expect(find.text('Time'), findsNothing);
    expect(find.text('Valid until'), findsNothing);

    final next = addInterval(
      testToday(),
      const CareInterval(3, IntervalUnit.month),
    );
    await tester.ensureVisible(find.text('Next time'));
    await tester.pumpAndSettle();
    expect(find.text(medium(next)), findsOneWidget);
    expect(find.text('Every 3 months from this date'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final (planId, input) = care.completions.single;
    expect(planId, 'plan1');
    expect(input.performedOn, testToday());
    expect(input.product, 'Milbemax');
    expect(input.nextDueOn, isNull, reason: 'the server works it out');
    expect(
      find.text('Marked as done. Next time: ${medium(next)}.'),
      findsOneWidget,
    );
    // Back on the Health tab, the plan is now months away.
    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Due soon'), findsNothing);
  });

  testWidgets('a vaccination: "valid until" sets the next date; or choose', (
    tester,
  ) async {
    care.plans = [
      testPlan(
        'rabies',
        kind: CareKind.vaccination,
        title: 'Rabies',
        interval: const CareInterval(1, IntervalUnit.year),
        targets: const [VaccineTarget.rabies],
        daysLeft: 3,
      ),
    ];
    await open(tester, '/pets/p1/plans/rabies/done');

    final now = testToday();
    final validUntil = DateTime(now.year + 3, now.month, now.day - 1);
    await pickDate(tester, 'Valid until', validUntil);
    await tester.ensureVisible(find.text('Next time'));
    await tester.pumpAndSettle();
    expect(find.text(medium(validUntil)), findsWidgets);
    expect(find.text('When the vaccine stops protecting'), findsOneWidget);

    // The vet set another date.
    final chosen = DateTime(now.year + 1, now.month, 1);
    await tapVisible(tester, find.text('Change'));
    await enterPickerDate(tester, chosen);
    expect(find.text(medium(chosen)), findsOneWidget);
    expect(find.text('Chosen by you'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final input = care.completions.single.$2;
    expect(input.validUntil, validUntil);
    expect(input.nextDueOn, chosen);
  });

  testWidgets('a lost response: the retry sends the same request id and the '
      'plan is marked done once', (tester) async {
    care.plans = [testPlan('plan1', daysLeft: 5)];
    await open(tester, '/pets/p1/plans/plan1/done');

    // "Done" goes through, but the answer never arrives.
    care.loseNextCompleteResponse = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.byType(DoneScreen), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(care.completeRequestIds, hasLength(2));
    expect(care.completeRequestIds.toSet(), hasLength(1), reason: 'same id');
    expect(care.completions, hasLength(1), reason: 'done once');
    expect(find.byType(DoneScreen), findsNothing);
  });

  testWidgets('the usual product is filled in; cleared, none is sent', (
    tester,
  ) async {
    care.plans = [testPlan('plan1', daysLeft: 5, defaultProduct: 'Milbemax')];
    await open(tester, '/pets/p1/plans/plan1/done');

    expect(
      tester.widget<TextFormField>(field('Product')).controller!.text,
      'Milbemax',
    );
    await tester.enterText(field('Product'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(care.completions.single.$2.product, isNull);
    expect(care.records.first.product, isNull);
  });

  testWidgets('"Valid from" starts on or after the day and not after "valid '
      'until"; a server error shows under it', (tester) async {
    care.plans = [
      testPlan(
        'rabies',
        kind: CareKind.vaccination,
        title: 'Rabies',
        interval: const CareInterval(1, IntervalUnit.year),
        targets: const [VaccineTarget.rabies],
        daysLeft: 3,
      ),
    ];
    await open(tester, '/pets/p1/plans/rabies/done');
    final now = testToday();

    // Protection that ends before it starts.
    await pickDate(tester, 'Valid from', DateTime(now.year, now.month + 2, 1));
    await pickDate(tester, 'Valid until', DateTime(now.year, now.month + 1, 1));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Must be after the date of the vaccination and the start'),
      findsOneWidget,
    );
    expect(care.completions, isEmpty);

    // A valid period, which the server refuses all the same.
    final validFrom = DateTime(now.year, now.month, now.day + 21);
    final validUntil = DateTime(now.year + 1, now.month, now.day);
    await pickDate(tester, 'Valid from', validFrom);
    await pickDate(tester, 'Valid until', validUntil);
    care.completeError = validationError({
      'validFrom': ["Protection can't start before the day it was given."],
    });
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text("This value wasn't accepted. Check it."), findsOneWidget);
    expect(find.text('Check the highlighted fields.'), findsOneWidget);

    care.completeError = null;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final input = care.completions.single.$2;
    expect(input.validFrom, validFrom);
    expect(input.validUntil, validUntil);
  });

  testWidgets('a lost response, then Back: the Health tab shows the plan as '
      'done; "Done" again the same day changes nothing', (tester) async {
    // Review probe "done_twice".
    care.plans = [testPlan('plan1', daysLeft: -2)];
    await open(tester, '/pets/p1?tab=health');
    expect(find.textContaining('2 days overdue'), findsOneWidget);

    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    // The server marks it done; the answer is lost.
    care.loseNextCompleteResponse = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(DoneScreen), findsOneWidget);

    // The user gives up. The lists were reloaded after the failure, so the
    // plan no longer looks due.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.textContaining('2 days overdue'), findsNothing);
    expect(find.text('Upcoming'), findsOneWidget);

    // "Done" again on the same day: the server gives the first answer.
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(care.completions, hasLength(1));
    expect(care.records, hasLength(1));
  });

  testWidgets('while saving nothing can be changed: the fields are off and '
      'no date picker opens', (tester) async {
    // Review probe "busy_picker".
    care.plans = [testPlan('plan1', daysLeft: 3)];
    await open(tester, '/pets/p1/plans/plan1/done');

    care.completeGate = Completer<void>();
    await tester.tap(find.text('Save'));
    await tester.pump();

    final notes = find.descendant(
      of: find.widgetWithText(CbTextField, 'Notes'),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(notes).enabled, isFalse);
    await tester.tap(
      find
          .descendant(
            of: find.byType(CbDateField).first,
            matching: find.byType(InkWell),
          )
          .first,
      warnIfMissed: false,
    );
    // The save bar spins: time is pumped instead of settling.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DatePickerDialog), findsNothing);

    care.completeGate!.complete();
    care.completeGate = null;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DoneScreen), findsNothing);
    expect(care.completions, hasLength(1));
  });

  testWidgets('a plan deleted elsewhere: the screen says so and closes', (
    tester,
  ) async {
    care.plans = [testPlan('plan1', daysLeft: 3)];
    await open(tester, '/pets/p1?tab=health');
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();

    // Another phone deletes the plan.
    care.plans.clear();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('This plan has been deleted, probably on another device.'),
      findsOneWidget,
    );
    expect(find.byType(DoneScreen), findsNothing);
    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.byTooltip('Done'), findsNothing, reason: 'the list reloaded');
  });

  testWidgets('the fields follow the kind', (tester) async {
    care.plans = [
      testPlan(
        'travel',
        kind: CareKind.echinococcus,
        title: 'Tapeworm treatment',
        interval: null,
        daysLeft: 2,
      ),
      testPlan(
        'exam',
        kind: CareKind.vetExam,
        title: 'Check-up',
        interval: const CareInterval(1, IntervalUnit.year),
        daysLeft: 2,
      ),
    ];
    await open(tester, '/pets/p1/plans/travel/done');
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Product'), findsOneWidget);
    await tester.ensureVisible(find.text('Next time'));
    await tester.pumpAndSettle();
    expect(
      find.text("This one-off plan finishes when it's done."),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Marked as done. The plan is finished.'), findsOneWidget);
    expect(care.plans.first.active, isFalse);

    await open(tester, '/pets/p1/plans/exam/done');
    expect(find.text('Time'), findsNothing);
    expect(find.text('Product'), findsNothing);
    expect(find.text('Batch number'), findsNothing);
    expect(find.text('Clinic'), findsOneWidget);
  });

  testWidgets('photos: uploaded first, attached one by one after "Done"; a '
      'retry neither uploads again nor marks done twice', (tester) async {
    care.plans = [testPlan('plan1', daysLeft: 5)];
    await open(tester, '/pets/p1/plans/plan1/done');
    await addPhotosFromLibrary(tester);
    expect(find.bySemanticsLabel('Photo 2'), findsOneWidget);

    care.addFileError = const ApiException(ApiErrorKind.network);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(files.uploads, hasLength(2));
    expect(care.completions, hasLength(1), reason: '"Done" went through');
    expect(care.filesAdded, isEmpty);
    expect(
      find.text(
        "Marked as done, but some photos weren't attached. Save again to "
        'attach them.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Already marked as done. Only the photos are left to attach.'),
      findsOneWidget,
    );
    expect(find.byType(DoneScreen), findsOneWidget, reason: 'the form stays');

    care.addFileError = null;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(files.uploads, hasLength(2), reason: 'nothing uploaded twice');
    expect(care.completions, hasLength(1), reason: 'never done twice');
    // One request per photo, to the record "Done" made.
    expect(care.filesAdded, [
      ('rec-done-1', 'upload-1'),
      ('rec-done-1', 'upload-2'),
    ]);
    expect(care.fileIds('rec-done-1'), ['upload-1', 'upload-2']);
    expect(find.byType(DoneScreen), findsNothing);
  });

  testWidgets('a refused photo stops before anything is saved', (tester) async {
    care.plans = [testPlan('plan1', daysLeft: 5)];
    await open(tester, '/pets/p1/plans/plan1/done');
    await addPhotosFromLibrary(tester);

    files.error = const ApiException(
      ApiErrorKind.payloadTooLarge,
      statusCode: 413,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(care.completions, isEmpty);
    expect(
      find.text('This file is too large. Upload files up to 15 MB.'),
      findsOneWidget,
    );

    // Without the photos, it saves.
    files.error = null;
    await tapVisible(tester, find.byTooltip('Remove photo 2'));
    await tapVisible(tester, find.byTooltip('Remove photo 1'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(care.completions, hasLength(1));
    expect(care.filesAdded, isEmpty);
  });

  testWidgets('the screen stays open while saving; when the app closes it '
      'anyway, Today is still refreshed', (tester) async {
    care.plans = [testPlan('plan1', daysLeft: 5)];
    await open(tester, '/pets/p1/plans/plan1/done');

    care.completeGate = Completer<void>();
    await tester.tap(find.text('Save'));
    await tester.pump();
    // The user tries to go back: the screen stays. (The spinner never
    // settles, so time is pumped instead.)
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DoneScreen), findsOneWidget);

    // The app closes it anyway, as a link or a sign-out would.
    appRouter(tester).go('/pets');
    await tester.pumpAndSettle();
    expect(find.byType(DoneScreen), findsNothing);

    care.completeGate!.complete();
    care.completeGate = null;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(care.completions, hasLength(1));

    // Today had the plan due in 5 days; it was reloaded after "Done".
    appRouter(tester).go('/today');
    await tester.pumpAndSettle();
    expect(find.text('Nothing scheduled yet'), findsOneWidget);
  });
}
