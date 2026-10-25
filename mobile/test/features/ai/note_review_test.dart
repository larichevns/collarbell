// The review of a note: the note quoted where a scan has its photos (with
// when it was written), to check the draft against what was written; no
// photos to keep; entries that say they come from the note; its records and
// weights saved together; the words of a note, not of a paper; and changes
// not dropped without asking, by Back or by the tab bar.
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/scan_screen.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pet_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

const note = 'Yesterday the rabies shot, Nobivac; weighs 4.2 kg';

final rabiesPlan = testPlan(
  'plan-rabies',
  kind: CareKind.vaccination,
  title: 'Rabies',
  interval: const CareInterval(1, IntervalUnit.year),
  targets: const [VaccineTarget.rabies],
  daysLeft: 20,
);

/// What AI read from [note]: a rabies vaccination, a "Done" of the rabies
/// plan, and the weight.
ScanDraft noteDraft() => ScanDraft(
  records: [
    DraftRecord(
      key: 0,
      kind: CareKind.vaccination,
      title: 'Rabies vaccination',
      performedOn: DateTime(2025, 10, 6),
      product: 'Nobivac',
      targets: const [VaccineTarget.rabies],
      evidence: 'Yesterday the rabies shot, Nobivac',
      planId: rabiesPlan.id,
    ),
  ],
  weights: [
    DraftWeight(
      key: 0,
      measuredOn: DateTime(2025, 10, 6),
      weightKg: 4.2,
      evidence: 'weighs 4.2 kg',
    ),
  ],
);

Finder entry(String key) => find.byKey(ValueKey(key));

Checkbox tickOf(WidgetTester tester, String key) => tester.widget<Checkbox>(
  find.descendant(of: entry(key), matching: find.byType(Checkbox)),
);

Future<void> tick(WidgetTester tester, String key) => tapVisible(
  tester,
  find.descendant(of: entry(key), matching: find.byType(Checkbox)),
);

/// The text of the snackbar on screen.
String? snackText(WidgetTester tester) {
  final bar = find.byType(SnackBar);
  if (bar.evaluate().isEmpty) return null;
  return (tester.widget<SnackBar>(bar).content as Text).data;
}

void main() {
  late FakeAiRepository ai;
  late FakeCareRepository care;

  setUp(() {
    ai = FakeAiRepository(status: testAiStatus);
    care = FakeCareRepository(plans: [rabiesPlan]);
  });

  Future<void> openReview(WidgetTester tester, [ScanDraft? draft]) {
    ai.scans['note-1'] = testNote(
      'note-1',
      text: note,
      status: ScanStatus.ready,
      draft: draft ?? noteDraft(),
    );
    return pumpApp(
      tester,
      location: '/pets/p1/scans/note-1',
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        care: care,
        ai: ai,
      ),
    );
  }

  testWidgets('the note is quoted where a scan has its photos; there are no '
      'photos to keep', (tester) async {
    await openReview(tester);

    expect(find.text('Check the note'), findsOneWidget);
    expect(
      find.text(
        "AI read these entries from your note. Check them against what you "
        "wrote, fix what's wrong, and untick what you don't want to save.",
      ),
      findsOneWidget,
    );
    expect(find.text('Your note'), findsOneWidget);
    expect(find.text('“$note”'), findsOneWidget);
    // When it was written: what its "yesterday" means.
    expect(find.textContaining('Written Oct 2, 2026, '), findsOneWidget);
    expect(find.text('Photos'), findsNothing);
    expect(find.byKey(const ValueKey('keepPhotos')), findsNothing);

    // Each entry with the words it came from, and no page to open.
    expect(find.text('From your note'), findsNWidgets(2));
    expect(find.text('“Yesterday the rabies shot, Nobivac”'), findsOneWidget);
    expect(find.text('“weighs 4.2 kg”'), findsOneWidget);
    expect(find.textContaining('Read on page'), findsNothing);

    // A record and a weight, both ticked.
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Weighings'), findsOneWidget);
    expect(tickOf(tester, 'record-0').value, isTrue);
    expect(tickOf(tester, 'weight-0').value, isTrue);
    expect(find.text('Mark as done in plan “Rabies”'), findsOneWidget);
    expect(find.text('Save 2 selected'), findsOneWidget);
    expect(find.text('Discard note'), findsOneWidget);
  });

  testWidgets('saving sends the record with its plan and the weight, and no '
      'photos; the summary says what was saved', (tester) async {
    ai.applyResult = const ScanResult(
      recordIds: ['rec-1'],
      plansMoved: 1,
      weightsAdded: 1,
    );
    await openReview(tester);

    await tester.tap(find.text('Save 2 selected'));
    await tester.pumpAndSettle();

    final (id, input) = ai.applies.single;
    expect(id, 'note-1');
    final record = input.records.single;
    expect(record.record.title, 'Rabies vaccination');
    expect(record.record.performedOn, DateTime(2025, 10, 6));
    expect(record.planId, rabiesPlan.id);
    final weight = input.weights.single;
    expect((weight.measuredOn, weight.weightKg), (DateTime(2025, 10, 6), 4.2));
    expect(input.keepPhotos, isFalse, reason: 'a note has none');

    expect(find.byType(ScanScreen), findsNothing);
    expect(find.byType(PetDetailScreen), findsOneWidget);
    expect(
      snackText(tester),
      'Saved 1 record · 1 plan updated · 1 weighing added',
    );
  });

  testWidgets('nothing ticked: nothing to save, as a note keeps no photos', (
    tester,
  ) async {
    await openReview(tester);

    await tick(tester, 'record-0');
    await tick(tester, 'weight-0');

    expect(find.text('Save the photos only'), findsNothing);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nothing to save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets("the AI's doubts speak of the note, not of a paper", (
    tester,
  ) async {
    await openReview(
      tester,
      ScanDraft(
        records: [
          DraftRecord(
            key: 0,
            kind: CareKind.deworming,
            title: 'Deworming',
            performedOn: DateTime(2025, 3, 4),
            evidence: 'dewormed 03/04',
            warnings: const [DraftWarning('performedOn', DraftIssue.ambiguous)],
          ),
          const DraftRecord(
            key: 1,
            kind: CareKind.fleaTick,
            title: 'Fleas and ticks',
            evidence: 'flea drops',
            warnings: [DraftWarning('performedOn', DraftIssue.unreadable)],
            selected: false,
          ),
          DraftRecord(
            key: 2,
            kind: CareKind.deworming,
            title: 'Deworming',
            performedOn: DateTime(2025, 3, 4),
            warnings: const [DraftWarning('performedOn', DraftIssue.repeated)],
            selected: false,
          ),
        ],
        weights: [
          DraftWeight(
            key: 0,
            measuredOn: DateTime(2025, 3, 4),
            evidence: 'weighed her',
            warnings: const [DraftWarning('weightKg', DraftIssue.unreadable)],
            selected: false,
          ),
        ],
      ),
    );

    expect(
      find.text('Day and month could be swapped. Check what you meant.'),
      findsOneWidget,
    );
    expect(find.text('Change to Apr 3, 2025'), findsOneWidget);
    expect(find.text("The note doesn't say. Enter it."), findsNWidgets(2));
    expect(find.text('The same entry is in the note twice.'), findsOneWidget);
    expect(find.textContaining('paper'), findsNothing);

    // The editor says so too, over the words the entry came from.
    await tapVisible(
      tester,
      find.descendant(of: entry('record-1'), matching: find.byTooltip('Edit')),
    );
    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.text('From your note'), findsOneWidget);
    expect(find.text('“flea drops”'), findsOneWidget);
    expect(find.text("The note doesn't say. Enter it."), findsOneWidget);
  });

  testWidgets('discarding a note asks first, in the words of a note', (
    tester,
  ) async {
    await openReview(tester);

    await tester.tap(find.text('Discard note'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this note?'), findsOneWidget);
    expect(
      find.text('Nothing from it is saved, and its text is deleted.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(ai.discarded, ['note-1']);
    expect(ai.applies, isEmpty);
    expect(find.byType(ScanScreen), findsNothing);
    expect(snackText(tester), 'Note discarded');
  });

  testWidgets('a note saved meanwhile can not be discarded, and says so', (
    tester,
  ) async {
    await openReview(tester);
    ai
      ..discardError = conflict
      ..scans['note-1'] = testNote(
        'note-1',
        status: ScanStatus.applied,
        result: const ScanResult(recordIds: ['rec-1'], weightsAdded: 1),
      );

    await tester.tap(find.text('Discard note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.byType(ScanScreen), findsNothing);
    expect(
      snackText(tester),
      'Saved 1 record · 1 weighing added (this note was saved already)',
    );
  });

  testWidgets('leaving with changes asks first: the note stays on the Health '
      'tab', (tester) async {
    await openReview(tester);

    await tick(tester, 'weight-0');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your changes here will be lost. The note stays on the Health tab '
        'to check later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping the tab again asks before it drops changes made here, '
      'in the words of a note', (tester) async {
    ai.scans['note-1'] = testNote(
      'note-1',
      text: note,
      status: ScanStatus.ready,
      draft: noteDraft(),
    );
    await pumpApp(
      tester,
      location: '/pets/p1?tab=health',
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        care: care,
        ai: ai,
      ),
    );
    appRouter(tester).push('/pets/p1/scans/note-1');
    await tester.pumpAndSettle();

    // No changes: the tab bar just goes back to the pet list.
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);

    appRouter(tester).push('/pets/p1/scans/note-1');
    await tester.pumpAndSettle();
    await tick(tester, 'weight-0');
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    expect(
      find.text(
        'Your changes here will be lost. The note stays on the Health tab '
        'to check later.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Check the note'), findsOneWidget);
    expect(tickOf(tester, 'weight-0').value, isFalse, reason: 'kept');

    // Under an entry's editor too: the tab bar would drop both.
    await tapVisible(
      tester,
      find.descendant(of: entry('weight-0'), matching: find.byTooltip('Edit')),
    );
    expect(find.text('Edit weighing'), findsOneWidget);
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit weighing'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(ai.discarded, isEmpty, reason: 'the note waits to be checked');
  });
}
