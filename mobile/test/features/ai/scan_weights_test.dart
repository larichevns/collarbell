// The weights of a draft, a note's or a scan's (a vet invoice's "weight
// 4.2 kg" without an examination), saved as weighings of the pet's weight
// log: what starts ticked and why not, the AI's doubts, the editor's checks
// (to the gram, above 0 and up to 200 kg, not in the future, not before the
// pet's exact birth date), exactly what a save sends, the server's errors on
// their entries, and the weight log reloaded after saving.
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/scan_screen.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/weight/weight_repository.dart';
import 'package:collarbell/shared/widgets/cb_date_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// Born on a day the owner knows: no weighing comes before it.
final murka = Pet(
  id: 'p1',
  name: 'Murka',
  species: PetSpecies.cat,
  birthDate: DateTime(2025, 6, 1),
);

/// What a vet invoice gave: a weight to save, one in the log already, one
/// given twice, one that can't be right, and one whose number wasn't read.
ScanDraft invoiceDraft() => ScanDraft(
  weights: [
    DraftWeight(
      key: 0,
      measuredOn: DateTime(2025, 9, 1),
      weightKg: 4.2,
      evidence: 'Weight 4.2 kg',
    ),
    DraftWeight(
      key: 1,
      measuredOn: DateTime(2025, 8, 1),
      weightKg: 4.1,
      warnings: const [DraftWarning('measuredOn', DraftIssue.alreadySaved)],
      duplicateOf: 'weighing-1',
      selected: false,
    ),
    DraftWeight(
      key: 2,
      measuredOn: DateTime(2025, 9, 1),
      weightKg: 4.2,
      warnings: const [DraftWarning('measuredOn', DraftIssue.repeated)],
      selected: false,
    ),
    DraftWeight(
      key: 3,
      measuredOn: DateTime(2025, 9, 15),
      weightKg: 425,
      warnings: const [DraftWarning('weightKg', DraftIssue.invalidFormat)],
      selected: false,
    ),
    DraftWeight(
      key: 4,
      measuredOn: DateTime(2025, 9, 20),
      warnings: const [DraftWarning('weightKg', DraftIssue.unreadable)],
      selected: false,
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

Future<void> edit(WidgetTester tester, String key) => tapVisible(
  tester,
  find.descendant(of: entry(key), matching: find.byTooltip('Edit')),
);

Finder weightField() => find.descendant(
  of: find.byKey(const ValueKey('weight')),
  matching: find.byType(TextFormField),
);

Finder inEntry(String key, String text) =>
    find.descendant(of: entry(key), matching: find.text(text));

/// The text of the snackbar on screen.
String? snackText(WidgetTester tester) {
  final bar = find.byType(SnackBar);
  if (bar.evaluate().isEmpty) return null;
  return (tester.widget<SnackBar>(bar).content as Text).data;
}

void main() {
  late FakeAiRepository ai;
  late FakeWeightRepository weight;

  setUp(() {
    ai = FakeAiRepository(status: testAiStatus);
    weight = FakeWeightRepository();
  });

  /// The review of a vet document's scan, or with [note] of a note.
  Future<void> openReview(
    WidgetTester tester,
    ScanDraft draft, {
    bool note = false,
  }) {
    ai.scans['scan-1'] = note
        ? testNote('scan-1', status: ScanStatus.ready, draft: draft)
        : testScan(
            'scan-1',
            source: ScanSource.vetDocument,
            status: ScanStatus.ready,
            pages: [testFile('page-1')],
            draft: draft,
          );
    return pumpApp(
      tester,
      location: '/pets/p1/scans/scan-1',
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        ai: ai,
        weight: weight,
      ),
    );
  }

  testWidgets('weights start as the server suggests: ticked, or unticked '
      'with why', (tester) async {
    await openReview(tester, invoiceDraft());

    expect(find.text('Weighings'), findsOneWidget);
    expect(tickOf(tester, 'weight-0').value, isTrue);
    expect(inEntry('weight-0', 'Weighing'), findsOneWidget);
    expect(inEntry('weight-0', '4.2 kg'), findsOneWidget);
    expect(inEntry('weight-0', 'Sep 1, 2025'), findsOneWidget);
    expect(inEntry('weight-0', 'Read on page 1'), findsOneWidget);
    expect(inEntry('weight-0', '“Weight 4.2 kg”'), findsOneWidget);

    // In the log already, or the same as an entry above: the user's choice.
    expect(tickOf(tester, 'weight-1').value, isFalse);
    expect(inEntry('weight-1', 'Already saved'), findsOneWidget);
    expect(
      inEntry('weight-1', 'This weight is already on the Weight tab.'),
      findsOneWidget,
    );
    expect(tickOf(tester, 'weight-2').value, isFalse);
    expect(inEntry('weight-2', 'Same as another entry'), findsOneWidget);
    expect(
      inEntry('weight-2', 'An entry above has the same weight.'),
      findsOneWidget,
    );

    // Saving would refuse it as it is: unticked, the doubt on the weight.
    expect(tickOf(tester, 'weight-3').value, isFalse);
    expect(inEntry('weight-3', '425 kg'), findsOneWidget);
    expect(
      inEntry(
        'weight-3',
        "This doesn't look right. Check it against the "
            'paper.',
      ),
      findsOneWidget,
    );

    // No number: it can't be ticked until one is entered.
    expect(tickOf(tester, 'weight-4').value, isFalse);
    expect(tickOf(tester, 'weight-4').onChanged, isNull);
    expect(inEntry('weight-4', 'Not read'), findsOneWidget);
    expect(
      inEntry('weight-4', 'Enter the weight to save this entry.'),
      findsOneWidget,
    );

    expect(find.text('Save 1 selected'), findsOneWidget);
  });

  testWidgets('saving sends only the ticked weights; the summary counts the '
      'weighings, and the weight log reloads', (tester) async {
    ai.applyResult = const ScanResult(weightsAdded: 2, documentId: 'doc-1');
    await openReview(tester, invoiceDraft());
    final app = ProviderScope.containerOf(
      tester.element(find.byType(ScanScreen)),
    );
    // Shown somewhere in the app: the log is loaded and watched.
    app.listen(weightLogProvider('p1'), (_, _) {});
    await tester.pumpAndSettle();
    final before = weight.listCalls;

    // Saved already, but the user wants it all the same.
    await tick(tester, 'weight-1');
    await tester.tap(find.text('Save 2 selected'));
    await tester.pumpAndSettle();

    final sent = ai.applies.single.$2.weights;
    expect(
      [for (final w in sent) (w.measuredOn, w.weightKg)],
      [(DateTime(2025, 9, 1), 4.2), (DateTime(2025, 8, 1), 4.1)],
    );
    expect(ai.applies.single.$2.keepPhotos, isTrue, reason: 'a scan');
    expect(snackText(tester), '2 weighings added · photos saved as a document');
    expect(weight.listCalls, greaterThan(before), reason: 'the weight log');
  });

  testWidgets('a weight out of range is caught before sending; its editor '
      'checks it like a weighing, to the gram', (tester) async {
    await openReview(tester, invoiceDraft());

    await tick(tester, 'weight-3');
    await tester.tap(find.text('Save 2 selected'));
    await tester.pumpAndSettle();
    expect(ai.applies, isEmpty);
    expect(
      inEntry('weight-3', 'Weight: Use a weight above 0 and up to 200 kg'),
      findsOneWidget,
    );

    await edit(tester, 'weight-3');
    expect(find.text('Edit weighing'), findsOneWidget);
    expect(tester.widget<TextFormField>(weightField()).controller!.text, '425');
    expect(
      find.text("This doesn't look right. Check it against the paper."),
      findsOneWidget,
      reason: "the AI's doubt under the field",
    );
    for (final (typed, problem) in [
      ('0', 'Use a weight above 0 and up to 200 kg'),
      ('200,001', 'Use a weight above 0 and up to 200 kg'),
      ('4.2345', 'Use 3 decimals at most'),
      ('', 'Enter the weight'),
    ]) {
      await tester.enterText(weightField(), typed);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text(problem), findsOneWidget, reason: typed);
      expect(find.text('Edit weighing'), findsOneWidget, reason: 'stays open');
    }
    await tester.enterText(weightField(), '4,235');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Edit weighing'), findsNothing);
    expect(inEntry('weight-3', '4.235 kg'), findsOneWidget);
    expect(
      find.text("This doesn't look right. Check it against the paper."),
      findsNothing,
      reason: 'the weight was changed',
    );
    await tester.tap(find.text('Save 2 selected'));
    await tester.pumpAndSettle();
    expect(
      [for (final w in ai.applies.single.$2.weights) w.weightKg],
      [4.2, 4.235],
    );
  });

  testWidgets('a weight the AI could not read is entered in its editor, '
      'which ticks it', (tester) async {
    await openReview(tester, invoiceDraft());

    await edit(tester, 'weight-4');
    expect(tester.widget<TextFormField>(weightField()).controller!.text, '');
    await tester.enterText(weightField(), '4,3');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(tickOf(tester, 'weight-4').value, isTrue);
    expect(inEntry('weight-4', '4.3 kg'), findsOneWidget);
    expect(find.text('Enter the weight to save this entry.'), findsNothing);
    await tester.tap(find.text('Save 2 selected'));
    await tester.pumpAndSettle();
    final sent = ai.applies.single.$2.weights.last;
    expect((sent.measuredOn, sent.weightKg), (DateTime(2025, 9, 20), 4.3));
  });

  testWidgets('a day before the pet was born, before 1990 or in the future '
      'is caught before sending, and fixed in the editor', (tester) async {
    final tomorrow = CbDateField.today().add(const Duration(days: 1));
    await openReview(
      tester,
      ScanDraft(
        weights: [
          DraftWeight(
            key: 0,
            measuredOn: DateTime(2025, 5, 1),
            weightKg: 3.1,
            warnings: const [
              DraftWarning('measuredOn', DraftIssue.invalidFormat),
            ],
            selected: false,
          ),
          DraftWeight(
            key: 1,
            measuredOn: DateTime(1989, 12, 31),
            weightKg: 3.2,
            warnings: const [
              DraftWarning('measuredOn', DraftIssue.invalidFormat),
            ],
            selected: false,
          ),
          DraftWeight(
            key: 2,
            measuredOn: tomorrow,
            weightKg: 3.3,
            warnings: const [DraftWarning('measuredOn', DraftIssue.inFuture)],
            selected: false,
          ),
        ],
      ),
      note: true,
    );
    expect(find.text('This date is in the future. Check it.'), findsOneWidget);

    for (final key in ['weight-0', 'weight-1', 'weight-2']) {
      await tick(tester, key);
    }
    await tester.tap(find.text('Save 3 selected'));
    await tester.pumpAndSettle();

    expect(ai.applies, isEmpty);
    expect(
      inEntry('weight-0', "Date: Can't be before the pet was born"),
      findsOneWidget,
    );
    expect(
      inEntry('weight-1', 'Date: Use a date in 1990 or later'),
      findsOneWidget,
    );
    expect(
      inEntry('weight-2', "Date: A date in the future can't be saved"),
      findsOneWidget,
    );

    await edit(tester, 'weight-0');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text("Can't be before the pet was born"), findsOneWidget);
    await pickDate(tester, 'Date', DateTime(2025, 7, 1));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(inEntry('weight-0', 'Jul 1, 2025'), findsOneWidget);

    // The other two left out: only the fixed one is sent.
    await tick(tester, 'weight-1');
    await tick(tester, 'weight-2');
    await tester.tap(find.text('Save 1 selected'));
    await tester.pumpAndSettle();
    final sent = ai.applies.single.$2.weights.single;
    expect((sent.measuredOn, sent.weightKg), (DateTime(2025, 7, 1), 3.1));
  });

  testWidgets('a day whose day and month may be swapped has "Change to …"', (
    tester,
  ) async {
    await openReview(
      tester,
      ScanDraft(
        weights: [
          DraftWeight(
            key: 0,
            measuredOn: DateTime(2025, 7, 8),
            weightKg: 4.2,
            warnings: const [DraftWarning('measuredOn', DraftIssue.ambiguous)],
          ),
        ],
      ),
    );
    expect(
      find.text('Day and month could be swapped. Check against the paper.'),
      findsOneWidget,
    );

    await tapVisible(tester, find.text('Change to Aug 7, 2025'));
    expect(inEntry('weight-0', 'Aug 7, 2025'), findsOneWidget);
    expect(find.text('Change to Aug 7, 2025'), findsNothing);
    await tester.tap(find.text('Save 1 selected'));
    await tester.pumpAndSettle();
    expect(
      ai.applies.single.$2.weights.single.measuredOn,
      DateTime(2025, 8, 7),
    );
  });

  testWidgets("the server's errors on a weight show on its entry", (
    tester,
  ) async {
    await openReview(tester, invoiceDraft(), note: true);
    ai.applyError = validationProblem({
      'weights[0].measuredOn': ['Use a date after the pet was born.'],
    });

    await tester.tap(find.text('Save 1 selected'));
    await tester.pumpAndSettle();

    expect(find.text('Check the highlighted fields.'), findsOneWidget);
    expect(
      inEntry('weight-0', "Date: This value wasn't accepted. Check it."),
      findsOneWidget,
    );
    expect(find.byType(ScanScreen), findsOneWidget, reason: 'still open');

    // Checked by the server again on the next save, as any field.
    ai.applyError = null;
    await tester.tap(find.text('Save 1 selected'));
    await tester.pumpAndSettle();
    expect(ai.applies, hasLength(2));
    expect(find.byType(ScanScreen), findsNothing);
  });
}
