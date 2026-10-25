// The review of a scan: what starts ticked, how the AI's doubts show, the
// date that blocks a tick until it is entered, the plan link, exactly what
// a save sends, the server's field errors put back on their entries, and
// a scan saved or discarded elsewhere.
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/scan_screen.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/passport/passport.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pet_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

final rabiesPlan = testPlan(
  'plan-rabies',
  kind: CareKind.vaccination,
  title: 'Rabies',
  interval: const CareInterval(1, IntervalUnit.year),
  targets: const [VaccineTarget.rabies],
  daysLeft: 20,
);
final dewormingPlan = testPlan('plan-deworm', daysLeft: 40);
final outdoorDewormingPlan = testPlan(
  'plan-deworm-outdoor',
  title: 'Deworming, outdoors',
  daysLeft: 60,
);

/// What the AI read from two passport pages: a rabies vaccination (its date
/// could be 3 December too) that is a "Done" of the rabies plan, a
/// deworming that is saved already, one whose date couldn't be read, a
/// flea treatment that is on both photos, a microchip, and the passport
/// details: the number differs from the saved one, the country and the
/// date of issue are as saved.
ScanDraft testDraft() => ScanDraft(
  records: [
    DraftRecord(
      key: 0,
      kind: CareKind.vaccination,
      title: 'Rabies vaccination',
      performedOn: DateTime(2025, 3, 12),
      product: 'Nobivac Rabies',
      manufacturer: 'MSD',
      batchNumber: 'A123B45',
      validUntil: DateTime(2028, 3, 11),
      targets: const [VaccineTarget.rabies],
      evidence: 'Nobivac Rabies, MSD · A123B45 · 12/03/2025',
      warnings: const [DraftWarning('performedOn', DraftIssue.ambiguous)],
      planId: 'plan-rabies',
    ),
    DraftRecord(
      key: 1,
      kind: CareKind.deworming,
      title: 'Deworming',
      performedOn: DateTime(2025, 1, 5),
      product: 'Milbemax',
      warnings: const [DraftWarning('performedOn', DraftIssue.alreadySaved)],
      duplicateOf: 'rec-old',
      selected: false,
    ),
    const DraftRecord(
      key: 2,
      kind: CareKind.deworming,
      title: 'Deworming',
      product: 'Drontal',
      evidence: 'Drontal ··/··/2024',
      page: 2,
      warnings: [DraftWarning('performedOn', DraftIssue.unreadable)],
      selected: false,
    ),
    DraftRecord(
      key: 3,
      kind: CareKind.fleaTick,
      title: 'Fleas and ticks',
      performedOn: DateTime(2025, 2, 1),
      product: 'Bravecto',
      page: 2,
      warnings: const [DraftWarning('performedOn', DraftIssue.repeated)],
      selected: false,
    ),
  ],
  identifiers: [
    DraftIdentifier(
      key: 0,
      type: IdentifierType.isoChip,
      code: '276098100123456',
      appliedOn: DateTime(2020, 3, 1),
      location: 'Left side of the neck',
      evidence: 'Transponder 276098100123456',
    ),
  ],
  passport: DraftPassport(
    number: 'DE0123456',
    issuingCountry: 'DE',
    issuedOn: DateTime(2020, 3, 1),
    evidence: 'DE0123456',
    warnings: const [
      DraftWarning('passportNumber', DraftIssue.differsFromSaved),
    ],
    selected: false,
  ),
);

Finder entry(String key) => find.byKey(ValueKey(key));

Checkbox tickOf(WidgetTester tester, String key) => tester.widget<Checkbox>(
  find.descendant(of: entry(key), matching: find.byType(Checkbox)),
);

Future<void> tick(WidgetTester tester, String key) => tapVisible(
  tester,
  find.descendant(of: entry(key), matching: find.byType(Checkbox)),
);

void main() {
  late FakeAiRepository ai;
  late FakeCareRepository care;
  late FakePetsRepository pets;
  late FakePassportRepository passport;

  setUp(() {
    ai = FakeAiRepository(
      status: testAiStatus,
      scans: [
        testScan(
          'scan-1',
          status: ScanStatus.ready,
          pages: [testFile('page-1'), testFile('page-2')],
          draft: testDraft(),
        ),
      ],
    );
    care = FakeCareRepository(
      plans: [rabiesPlan, dewormingPlan, outdoorDewormingPlan],
    );
    pets = FakePetsRepository([murka]);
    passport = FakePassportRepository(
      Passport(
        number: 'DE0999999',
        issuingCountry: 'DE',
        issuedOn: DateTime(2020, 3, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
  });

  Future<void> openReview(WidgetTester tester) => pumpApp(
    tester,
    location: '/pets/p1/scans/scan-1',
    overrides: fakeRepositories(
      pets: pets,
      care: care,
      passport: passport,
      ai: ai,
    ),
  );

  testWidgets('starts as the server suggests: duplicates unticked, doubts '
      'shown, the record linked to its plan', (tester) async {
    await openReview(tester);

    expect(find.text('Check the scan'), findsOneWidget);
    expect(tickOf(tester, 'record-0').value, isTrue);
    expect(
      find.text('Day and month could be swapped. Check against the paper.'),
      findsOneWidget,
    );
    expect(find.text('Change to Dec 3, 2025'), findsOneWidget);
    expect(
      find.text('Mark as done in plan “Rabies”'),
      findsOneWidget,
      reason: 'linked to the rabies plan',
    );
    expect(
      find.text('“Nobivac Rabies, MSD · A123B45 · 12/03/2025”'),
      findsOneWidget,
    );

    // Saved already, and repeated on another photo: unticked, with badges.
    expect(tickOf(tester, 'record-1').value, isFalse);
    expect(find.text('Already saved'), findsOneWidget);
    expect(
      find.text('The same entry is already in the history.'),
      findsOneWidget,
    );
    expect(tickOf(tester, 'record-3').value, isFalse);
    expect(find.text('Same as another entry'), findsOneWidget);

    // The microchip is ticked; the passport number differs from the saved
    // one, so it waits for the user, and the rest is saved already.
    expect(tickOf(tester, 'identifier-0').value, isTrue);
    expect(find.text('276 098 100 123 456'), findsOneWidget);
    expect(tickOf(tester, 'passport').value, isFalse);
    expect(find.text('Saved: DE0999999'), findsOneWidget);
    expect(find.text("Differs from what's saved"), findsOneWidget);
    expect(find.text('Already in the passport details'), findsNWidgets(2));
    final replace = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('replace-passportNumber')),
    );
    expect(replace.value, isFalse, reason: 'nothing saved is replaced quietly');

    // A vaccination and a microchip; the photos are kept by default.
    expect(find.text('Save 2 selected'), findsOneWidget);
    final keepPhotos = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('keepPhotos')),
    );
    expect(keepPhotos.value, isTrue);
  });

  testWidgets('a date the AI could not read blocks the tick until it is '
      'entered', (tester) async {
    await openReview(tester);

    final checkbox = tickOf(tester, 'record-2');
    expect(checkbox.value, isFalse);
    expect(checkbox.onChanged, isNull, reason: 'no date, nothing to save');
    expect(find.text('Enter the date to save this entry.'), findsOneWidget);
    expect(find.text('Not read'), findsOneWidget);

    await tapVisible(tester, find.text('Enter the date'));
    await enterPickerDate(tester, DateTime(2024, 11, 20));

    expect(tickOf(tester, 'record-2').value, isTrue);
    expect(tickOf(tester, 'record-2').onChanged, isNotNull);
    expect(find.text('Enter the date to save this entry.'), findsNothing);
    expect(find.text('Save 3 selected'), findsOneWidget);
  });

  testWidgets('saving sends the ticked entries as left: records with their '
      'plan, the microchip, the passport details, the photo choice', (
    tester,
  ) async {
    await openReview(tester);

    // The day and month were the other way round.
    await tapVisible(tester, find.text('Change to Dec 3, 2025'));
    expect(
      find.text('Day and month could be swapped. Check against the paper.'),
      findsNothing,
    );
    // Replacing the saved passport number ticks the card.
    await tapVisible(
      tester,
      find.byKey(const ValueKey('replace-passportNumber')),
    );
    expect(tickOf(tester, 'passport').value, isTrue);
    await tapVisible(tester, find.byKey(const ValueKey('keepPhotos')));
    ai.applyResult = const ScanResult(
      recordIds: ['rec-1'],
      plansMoved: 1,
      identifiersAdded: 1,
      passportUpdated: true,
    );
    await tester.tap(find.text('Save 3 selected'));
    await tester.pumpAndSettle();

    final (id, input) = ai.applies.single;
    expect(id, 'scan-1');
    final record = input.records.single;
    expect(record.planId, 'plan-rabies');
    expect(record.record.kind, CareKind.vaccination);
    expect(record.record.title, 'Rabies vaccination');
    expect(record.record.performedOn, DateTime(2025, 12, 3));
    expect(record.record.product, 'Nobivac Rabies');
    expect(record.record.manufacturer, 'MSD');
    expect(record.record.batchNumber, 'A123B45');
    expect(record.record.validUntil, DateTime(2028, 3, 11));
    expect(record.record.targets, [VaccineTarget.rabies]);
    final chip = input.identifiers.single;
    expect(chip.type, IdentifierType.isoChip);
    expect(chip.code, '276098100123456');
    expect(chip.appliedOn, DateTime(2020, 3, 1));
    expect(chip.location, 'Left side of the neck');
    // Only what changes: the country and the date are as saved.
    expect(input.passport?.number, 'DE0123456');
    expect(input.passport?.issuingCountry, isNull);
    expect(input.passport?.issuedOn, isNull);
    expect(input.keepPhotos, isFalse);

    // Back on the pet's page, with what was saved.
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.byType(PetDetailScreen), findsOneWidget);
    expect(
      find.text(
        'Saved 1 record · 1 plan updated · 1 microchip or tattoo added · '
        'passport details updated: number',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the plan link can be turned off, or set to another plan of '
      'the kind', (tester) async {
    await openReview(tester);

    // The rabies vaccination without its plan: history only.
    await tapVisible(
      tester,
      find.descendant(of: entry('record-0'), matching: find.byType(Switch)),
    );
    expect(find.text('Mark as done in a plan'), findsWidgets);

    // The saved deworming, ticked anyway, as a "Done" of the outdoor plan:
    // there are two deworming plans to choose from.
    await tick(tester, 'record-1');
    await tapVisible(
      tester,
      find.descendant(of: entry('record-1'), matching: find.byType(Switch)),
    );
    expect(find.text('Mark as done in which plan?'), findsOneWidget);
    await tester.tap(find.text('Deworming, outdoors'));
    await tester.pumpAndSettle();
    expect(
      find.text('Mark as done in plan “Deworming, outdoors”'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save 3 selected'));
    await tester.pumpAndSettle();

    final records = ai.applies.single.$2.records;
    expect([for (final r in records) r.planId], [null, 'plan-deworm-outdoor']);
  });

  testWidgets('a linked plan deleted meanwhile stays linked until the '
      'switch is turned off', (tester) async {
    await openReview(tester);
    // The plan goes on another phone; a failed save reloads the plans.
    care.plans.remove(rabiesPlan);
    ai.applyError = networkError;
    await tester.tap(find.text('Save 2 selected'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as done in plan “Rabies”'), findsNothing);
    final link = find.descendant(
      of: entry('record-0'),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(link).value, isTrue);

    await tapVisible(tester, link);
    ai.applyError = null;
    await tester.tap(find.text('Save 2 selected'));
    await tester.pumpAndSettle();
    expect(ai.applies.last.$2.records.single.planId, isNull);
  });

  testWidgets('an entry edited in its editor is saved as edited', (
    tester,
  ) async {
    await openReview(tester);

    await tapVisible(
      tester,
      find.descendant(of: entry('record-0'), matching: find.byTooltip('Edit')),
    );
    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.text('Read on page 1'), findsOneWidget);
    final product = find.descendant(
      of: find.byKey(const ValueKey('product')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(product, 'Rabisin');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Edit entry'), findsNothing);
    expect(find.text('Rabisin, MSD'), findsOneWidget);
    await tester.tap(find.text('Save 2 selected'));
    await tester.pumpAndSettle();
    expect(ai.applies.single.$2.records.single.record.product, 'Rabisin');
  });

  testWidgets('a value the server refuses shows on its entry, which is '
      'scrolled into view', (tester) async {
    await openReview(tester);
    // Sent as records[0] (the vaccination) and records[1] (the fleas).
    await tick(tester, 'record-3');
    ai.applyError = validationProblem({
      'records[1].record.performedOn': ['The date is after today.'],
      'identifiers[0].code': ['An ISO microchip number has 15 digits.'],
    });

    // Back to the top: the refused entries are out of view.
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save 3 selected'));
    await tester.pumpAndSettle();

    expect(find.text('Check the highlighted fields.'), findsOneWidget);
    expect(
      find
          .descendant(
            of: entry('record-3'),
            matching: find.text("Date: This value wasn't accepted. Check it."),
          )
          .hitTestable(),
      findsOneWidget,
      reason: 'the topmost refused entry is scrolled to',
    );
    expect(
      find.descendant(
        of: entry('identifier-0'),
        matching: find.text(
          "Chip number: This value wasn't accepted. Check it.",
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(ScanScreen), findsOneWidget, reason: 'still open');

    // The fleas unticked; the chip number is checked by the server again,
    // as on any save, and this time it passes.
    ai.applyError = null;
    await tick(tester, 'record-3');
    await tester.tap(find.text('Save 2 selected'));
    await tester.pumpAndSettle();
    expect(ai.applies, hasLength(2));
    expect(ai.applies.last.$2.records, hasLength(1));
    expect(ai.applies.last.$2.identifiers, hasLength(1));
    expect(find.byType(ScanScreen), findsNothing);
  });

  testWidgets('a local mistake is caught before sending', (tester) async {
    // A passport number with a character the server refuses, for a
    // passport header without one.
    passport.passport = const Passport();
    ai.scans['scan-1'] = testScan(
      'scan-1',
      status: ScanStatus.ready,
      draft: const ScanDraft(passport: DraftPassport(number: 'DE 01#23')),
    );
    await openReview(tester);

    await tester.tap(find.text('Save 1 selected'));
    await tester.pumpAndSettle();

    expect(ai.applies, isEmpty);
    expect(
      find.text(
        'Passport number: Use up to 30 letters, digits, hyphens and slashes',
      ),
      findsOneWidget,
    );
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
  });

  testWidgets('saved elsewhere meanwhile (409): the scan shows as saved', (
    tester,
  ) async {
    await openReview(tester);
    ai.applyError = conflict;
    ai.scans['scan-1'] = testScan(
      'scan-1',
      status: ScanStatus.applied,
      result: const ScanResult(recordIds: ['r1', 'r2']),
    );

    await tester.tap(find.text('Save 2 selected'));
    await tester.pumpAndSettle();

    expect(find.text('Check the scan'), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Saved 2 records'), findsOneWidget);
  });

  testWidgets('discarding asks first; then nothing is saved', (tester) async {
    await openReview(tester);

    await tester.tap(find.text('Discard scan'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this scan?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(ai.discarded, isEmpty);

    await tester.tap(find.text('Discard scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(ai.discarded, ['scan-1']);
    expect(ai.applies, isEmpty);
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.text('Scan discarded'), findsOneWidget);
  });

  testWidgets('nothing ticked: only the photos can be saved', (tester) async {
    await openReview(tester);

    await tick(tester, 'record-0');
    await tick(tester, 'identifier-0');
    expect(find.text('Save the photos only'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('keepPhotos')));
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nothing to save'),
    );
    expect(save.onPressed, isNull);
  });
}
