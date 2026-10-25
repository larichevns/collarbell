// The review's rules beyond its first look: passport details change only
// what the user agrees to, microchips stay within the pet's limit, dates
// are checked like the record form's (with "Change to …" where day and
// month may be swapped), titles the page doesn't give are named in the
// user's language, a plan link follows the record's kind, the server's
// field errors find their entries, a save whose answer is lost is checked
// with the server, leaving with changes asks first, and a save reloads
// every list it can change.
import 'package:collarbell/app/app_settings.dart';
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/ai_repository.dart';
import 'package:collarbell/features/ai/scan_screen.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/care_repository.dart';
import 'package:collarbell/features/documents/documents_repository.dart';
import 'package:collarbell/features/passport/passport.dart';
import 'package:collarbell/features/passport/passport_repository.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/features/today/today_repository.dart';
import 'package:collarbell/features/weight/weight_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
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

/// A rabies vaccination that is a "Done" of [rabiesPlan].
DraftRecord rabiesShot({String? title = 'Rabies vaccination'}) => DraftRecord(
  key: 0,
  kind: CareKind.vaccination,
  title: title,
  performedOn: DateTime(2025, 3, 12),
  targets: const [VaccineTarget.rabies],
  planId: rabiesPlan.id,
);

DraftIdentifier chip(
  int key,
  String code, {
  bool selected = true,
  List<DraftWarning> warnings = const [],
  DateTime? appliedOn,
}) => DraftIdentifier(
  key: key,
  type: IdentifierType.isoChip,
  code: code,
  appliedOn: appliedOn,
  warnings: warnings,
  selected: selected,
);

PetIdentifier savedChip(String code) =>
    PetIdentifier(type: IdentifierType.isoChip, code: code, rawCode: code);

/// A check-up the scan read, with the pet's weight.
DraftRecord checkUp({
  double? weightKg = 4.25,
  List<DraftWarning> warnings = const [],
}) => DraftRecord(
  key: 0,
  kind: CareKind.vetExam,
  title: 'Annual check-up',
  performedOn: DateTime(2025, 6, 10),
  weightKg: weightKg,
  warnings: warnings,
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
  late FakePetsRepository pets;
  late FakePassportRepository passport;
  late FakeDocumentsRepository documents;
  late FakeTodayRepository today;
  late FakeWeightRepository weight;

  setUp(() {
    ai = FakeAiRepository(status: testAiStatus);
    care = FakeCareRepository(plans: [rabiesPlan]);
    pets = FakePetsRepository([murka]);
    passport = FakePassportRepository(
      Passport(number: 'DE0999999', updatedAt: DateTime.utc(2026, 9, 1)),
    );
    documents = FakeDocumentsRepository();
    today = FakeTodayRepository();
    weight = FakeWeightRepository(care: care);
  });

  List<Override> overrides() => fakeRepositories(
    pets: pets,
    care: care,
    passport: passport,
    documents: documents,
    today: today,
    ai: ai,
    weight: weight,
  );

  Future<void> openReview(
    WidgetTester tester,
    ScanDraft draft, {
    String language = 'en',
  }) {
    ai.scans['scan-1'] = testScan(
      'scan-1',
      status: ScanStatus.ready,
      pages: [testFile('page-1'), testFile('page-2')],
      draft: draft,
    );
    return pumpApp(
      tester,
      location: '/pets/p1/scans/scan-1',
      language: language,
      overrides: overrides(),
    );
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ScanScreen)));

  group('passport details', () {
    final scanned = DraftPassport(
      number: 'DE0123456',
      issuingCountry: 'DE',
      issuedOn: DateTime(2020, 3, 1),
      warnings: const [
        DraftWarning('passportNumber', DraftIssue.differsFromSaved),
      ],
      selected: false,
    );

    testWidgets('empty fields are filled in; a saved value that differs '
        'stays', (tester) async {
      ai.applyResult = const ScanResult(passportUpdated: true);
      await openReview(tester, ScanDraft(passport: scanned));

      // The country and the date are new: the card is ticked for them.
      expect(tickOf(tester, 'passport').value, isTrue);
      expect(find.text('Saved: DE0999999'), findsOneWidget);
      final replace = find.byKey(const ValueKey('replace-passportNumber'));
      expect(tester.widget<SwitchListTile>(replace).value, isFalse);

      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();

      final sent = ai.applies.single.$2.passport!;
      expect(sent.number, isNull, reason: 'the saved number stays');
      expect(sent.issuingCountry, 'DE');
      expect(sent.issuedOn, DateTime(2020, 3, 1));
      expect(
        snackText(tester),
        'Passport details updated: country, date of issue',
      );
    });

    testWidgets('a saved value is replaced when the user switches it on', (
      tester,
    ) async {
      ai.applyResult = const ScanResult(passportUpdated: true);
      await openReview(tester, ScanDraft(passport: scanned));

      await tapVisible(
        tester,
        find.byKey(const ValueKey('replace-passportNumber')),
      );
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();

      final sent = ai.applies.single.$2.passport!;
      expect(sent.number, 'DE0123456');
      expect(sent.issuingCountry, 'DE');
      expect(
        snackText(tester),
        'Passport details updated: number, country, date of issue',
      );
    });

    testWidgets('a value changed by hand replaces the saved one', (
      tester,
    ) async {
      await openReview(tester, ScanDraft(passport: scanned));

      await tapVisible(
        tester,
        find.descendant(
          of: entry('passport'),
          matching: find.byTooltip('Edit'),
        ),
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('passportNumber')),
          matching: find.byType(TextFormField),
        ),
        'DE0123457',
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final replace = find.byKey(const ValueKey('replace-passportNumber'));
      expect(tester.widget<SwitchListTile>(replace).value, isTrue);
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies.single.$2.passport!.number, 'DE0123457');
    });

    testWidgets('nothing new: the card can not be ticked', (tester) async {
      passport.passport = Passport(
        number: 'DE0123456',
        issuingCountry: 'DE',
        issuedOn: DateTime(2020, 3, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      );
      await openReview(tester, ScanDraft(passport: scanned));

      expect(tickOf(tester, 'passport').value, isFalse);
      expect(tickOf(tester, 'passport').onChanged, isNull);
      expect(
        find.text('Nothing new: the passport details already say this.'),
        findsOneWidget,
      );
      expect(find.text('Already in the passport details'), findsNWidgets(3));
      expect(find.text('Save the photos only'), findsOneWidget);
    });

    testWidgets('a date of issue whose day and month may be swapped has '
        '"Change to …"', (tester) async {
      await openReview(
        tester,
        ScanDraft(
          passport: DraftPassport(
            issuedOn: DateTime(2020, 3, 4),
            warnings: const [DraftWarning('issuedOn', DraftIssue.ambiguous)],
          ),
        ),
      );

      await tapVisible(tester, find.text('Change to Apr 3, 2020'));
      expect(find.text('Apr 3, 2020'), findsOneWidget);
      expect(find.text('Change to Apr 3, 2020'), findsNothing);
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies.single.$2.passport!.issuedOn, DateTime(2020, 4, 3));
    });
  });

  group('microchips and tattoos', () {
    testWidgets('an implant date whose day and month may be swapped has '
        '"Change to …"', (tester) async {
      await openReview(
        tester,
        ScanDraft(
          identifiers: [
            chip(
              0,
              '276098100123456',
              appliedOn: DateTime(2020, 3, 4),
              warnings: const [DraftWarning('appliedOn', DraftIssue.ambiguous)],
            ),
          ],
        ),
      );

      await tapVisible(tester, find.text('Change to Apr 3, 2020'));
      expect(find.text('Change to Apr 3, 2020'), findsNothing);
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      expect(
        ai.applies.single.$2.identifiers.single.appliedOn,
        DateTime(2020, 4, 3),
      );
    });

    testWidgets('the pet keeps to 5; a number it has takes no place, and the '
        'summary says it was there already', (tester) async {
      pets = FakePetsRepository([
        Pet(
          id: murka.id,
          name: murka.name,
          species: murka.species,
          identifiers: [
            for (var i = 1; i <= 4; i++) savedChip('27609810000000$i'),
          ],
        ),
      ]);
      ai.applyResult = const ScanResult(identifiersAdded: 1);
      await openReview(
        tester,
        ScanDraft(
          identifiers: [
            chip(
              0,
              '276098100000001',
              selected: false,
              warnings: const [DraftWarning('code', DraftIssue.alreadySaved)],
            ),
            chip(1, '276098100000005'),
            chip(2, '276098100000006'),
          ],
        ),
      );

      await tester.tap(find.text('Save 2 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies, isEmpty);
      expect(
        find.descendant(
          of: entry('identifier-2'),
          matching: find.text('A pet can have up to 5 microchips and tattoos.'),
        ),
        findsOneWidget,
      );

      // One new number fits; the one the pet has takes no place.
      await tick(tester, 'identifier-2');
      await tick(tester, 'identifier-0');
      await tester.tap(find.text('Save 2 selected'));
      await tester.pumpAndSettle();
      final sent = ai.applies.single.$2.identifiers;
      expect(
        [for (final i in sent) i.code],
        ['276098100000001', '276098100000005'],
      );
      expect(
        snackText(tester),
        '1 microchip or tattoo added · 1 number was already on the pet',
      );
    });
  });

  group('records', () {
    testWidgets('a date before 1990 is caught before sending', (tester) async {
      await openReview(
        tester,
        ScanDraft(
          records: [
            DraftRecord(
              key: 0,
              kind: CareKind.deworming,
              title: 'Deworming',
              performedOn: DateTime(1989, 12, 31),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies, isEmpty);
      expect(find.text('Date: Use a date in 1990 or later'), findsOneWidget);
    });

    testWidgets('a title the page does not give is named in the user\'s '
        'language and saved so', (tester) async {
      await openReview(
        tester,
        ScanDraft(
          records: [
            rabiesShot(title: null),
            DraftRecord(
              key: 1,
              kind: CareKind.deworming,
              performedOn: DateTime(2025, 1, 5),
            ),
          ],
        ),
      );

      expect(find.text('Rabies vaccination'), findsOneWidget);
      expect(find.text('Deworming'), findsOneWidget, reason: 'said once');
      await tester.tap(find.text('Save 2 selected'));
      await tester.pumpAndSettle();
      expect(
        [for (final r in ai.applies.single.$2.records) r.record.title],
        ['Rabies vaccination', 'Deworming'],
      );
    });

    testWidgets('in Russian too', (tester) async {
      await openReview(
        tester,
        ScanDraft(
          records: [
            rabiesShot(title: null),
            DraftRecord(
              key: 1,
              kind: CareKind.deworming,
              performedOn: DateTime(2025, 1, 5),
            ),
          ],
        ),
        language: 'ru',
      );
      expect(find.text('Вакцинация против бешенства'), findsOneWidget);
      expect(find.text('Обработка от глистов'), findsOneWidget);
      await tester.tap(find.text('Сохранить выбранное (2)'));
      await tester.pumpAndSettle();
      expect(
        [for (final r in ai.applies.single.$2.records) r.record.title],
        ['Вакцинация против бешенства', 'Обработка от глистов'],
      );
    });

    testWidgets('a title the page does not give follows the language; one '
        'the user writes stays', (tester) async {
      await openReview(
        tester,
        ScanDraft(
          records: [
            rabiesShot(title: null),
            DraftRecord(
              key: 1,
              kind: CareKind.deworming,
              performedOn: DateTime(2025, 1, 5),
            ),
          ],
        ),
      );
      expect(find.text('Rabies vaccination'), findsOneWidget);

      // The deworming gets a title of its own.
      await tapVisible(
        tester,
        find.descendant(
          of: entry('record-1'),
          matching: find.byTooltip('Edit'),
        ),
      );
      final title = find.descendant(
        of: find.byKey(const ValueKey('title')),
        matching: find.byType(TextFormField),
      );
      expect(tester.widget<TextFormField>(title).controller!.text, 'Deworming');
      await tester.enterText(title, 'Milbemax course');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Russian, chosen while the review is open (More is another tab).
      await container(
        tester,
      ).read(appSettingsProvider.notifier).setLanguage(LanguagePreference.ru);
      await tester.pumpAndSettle();
      expect(find.text('Вакцинация против бешенства'), findsOneWidget);
      expect(find.text('Milbemax course'), findsOneWidget);

      await tester.tap(find.text('Сохранить выбранное (2)'));
      await tester.pumpAndSettle();
      expect(
        [for (final r in ai.applies.single.$2.records) r.record.title],
        ['Вакцинация против бешенства', 'Milbemax course'],
      );
    });

    testWidgets('another kind unlinks the plan, and an untouched title '
        'follows the kind', (tester) async {
      await openReview(tester, ScanDraft(records: [rabiesShot(title: null)]));
      expect(find.text('Mark as done in plan “Rabies”'), findsOneWidget);

      await tapVisible(
        tester,
        find.descendant(
          of: entry('record-0'),
          matching: find.byTooltip('Edit'),
        ),
      );
      await tapVisible(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('kind')),
          matching: find.text('Vaccination'),
        ),
      );
      await tester.tap(find.text('Deworming').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as done in plan “Rabies”'), findsNothing);
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      final sent = ai.applies.single.$2.records.single;
      expect(sent.record.kind, CareKind.deworming);
      expect(sent.record.title, 'Deworming');
      expect(sent.planId, isNull);
    });

    testWidgets('other diseases unlink the plan', (tester) async {
      await openReview(tester, ScanDraft(records: [rabiesShot()]));

      await tapVisible(
        tester,
        find.descendant(
          of: entry('record-0'),
          matching: find.byTooltip('Edit'),
        ),
      );
      await tapVisible(tester, find.widgetWithText(FilterChip, 'Rabies'));
      await tapVisible(
        tester,
        find.widgetWithText(FilterChip, 'Panleukopenia (FPV)'),
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // No plan against these diseases: the link is gone.
      expect(find.text('Mark as done in plan “Rabies”'), findsNothing);
      expect(
        find.descendant(of: entry('record-0'), matching: find.byType(Switch)),
        findsNothing,
      );
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      final sent = ai.applies.single.$2.records.single;
      expect(sent.record.targets, [VaccineTarget.fpv]);
      expect(sent.planId, isNull);
      expect(sent.record.title, 'Rabies vaccination', reason: 'as read');
    });

    testWidgets('a plan made on another phone after the Health tab loaded is '
        'offered: the review loads the plans afresh', (tester) async {
      care.plans.clear();
      ai.scans['scan-1'] = testScan(
        'scan-1',
        status: ScanStatus.ready,
        draft: ScanDraft(records: [rabiesShot()]),
      );
      await pumpApp(
        tester,
        location: '/pets/p1?tab=health',
        overrides: overrides(),
      );
      care.plans.add(rabiesPlan);
      appRouter(tester).push('/pets/p1/scans/scan-1');
      await tester.pumpAndSettle();

      expect(find.text('Mark as done in plan “Rabies”'), findsOneWidget);
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies.single.$2.records.single.planId, rabiesPlan.id);
    });
  });

  group("a check-up's weight", () {
    Finder weightField() => find.descendant(
      of: find.byKey(const ValueKey('weight')),
      matching: find.byType(TextFormField),
    );

    Future<void> edit(WidgetTester tester) => tapVisible(
      tester,
      find.descendant(of: entry('record-0'), matching: find.byTooltip('Edit')),
    );

    testWidgets('shows on the entry and is sent when saving', (tester) async {
      await openReview(tester, ScanDraft(records: [checkUp()]));

      expect(
        find.descendant(of: entry('record-0'), matching: find.text('Weight')),
        findsOneWidget,
      );
      expect(find.text('4.25 kg'), findsOneWidget);
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();

      final sent = ai.applies.single.$2.records.single.record;
      expect((sent.kind, sent.weightKg), (CareKind.vetExam, 4.25));
    });

    testWidgets("is changed in the entry's editor; another kind drops it", (
      tester,
    ) async {
      await openReview(tester, ScanDraft(records: [checkUp()]));

      await edit(tester);
      expect(
        tester.widget<TextFormField>(weightField()).controller!.text,
        '4.25',
      );
      await tester.enterText(weightField(), '4,3');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('4.3 kg'), findsOneWidget);

      // Only a check-up keeps a weight: the field goes with the kind.
      await edit(tester);
      await tapVisible(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('kind')),
          matching: find.text('Check-up'),
        ),
      );
      await tester.tap(find.text('Dental care').last);
      await tester.pumpAndSettle();
      expect(weightField(), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('4.3 kg'), findsNothing);

      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      final sent = ai.applies.single.$2.records.single.record;
      expect((sent.kind, sent.weightKg), (CareKind.dental, null));
    });

    testWidgets("the AI's doubt shows on the entry and its field until the "
        'weight is changed; a weight out of range is not sent', (tester) async {
      const doubt = "This doesn't look right. Check it against the paper.";
      await openReview(
        tester,
        ScanDraft(
          records: [
            checkUp(
              weightKg: 425,
              warnings: const [
                DraftWarning('weightKg', DraftIssue.invalidFormat),
              ],
            ),
          ],
        ),
      );
      expect(find.text('425 kg'), findsOneWidget);
      expect(
        find.descendant(of: entry('record-0'), matching: find.text(doubt)),
        findsOneWidget,
      );

      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies, isEmpty);
      expect(
        find.text('Weight: Use a weight above 0 and up to 200 kg'),
        findsOneWidget,
      );

      await edit(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('weight')),
          matching: find.text(doubt),
        ),
        findsOneWidget,
      );
      // A check-up record keeps its weight to 10 g.
      await tester.enterText(weightField(), '4.255');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Use 2 decimals at most'), findsOneWidget);
      await tester.enterText(weightField(), '4.25');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text(doubt), findsNothing);

      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies.single.$2.records.single.record.weightKg, 4.25);
    });
  });

  group("the server's field errors", () {
    testWidgets('on a plan link and on passport details', (tester) async {
      passport.passport = const Passport();
      await openReview(
        tester,
        ScanDraft(
          records: [rabiesShot()],
          passport: const DraftPassport(issuingCountry: 'DE'),
        ),
      );
      ai.applyError = validationProblem({
        'records[0].planId': ['The plan was deleted.'],
        'passport.issuingCountry': ['Use the two-letter country code.'],
      });

      await tester.tap(find.text('Save 2 selected'));
      await tester.pumpAndSettle();

      expect(find.text('Check the highlighted fields.'), findsOneWidget);
      expect(
        find.descendant(
          of: entry('record-0'),
          matching: find.text(
            "Care plan: This value wasn't accepted. Check it.",
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: entry('passport'),
          matching: find.text(
            "Issuing country: This value wasn't accepted. Check it.",
          ),
        ),
        findsOneWidget,
      );

      // Unlinked, the plan error goes; the server checks the rest again.
      ai.applyError = null;
      await tapVisible(
        tester,
        find.descendant(of: entry('record-0'), matching: find.byType(Switch)),
      );
      await tester.tap(find.text('Save 2 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies, hasLength(2));
      expect(ai.applies.last.$2.records.single.planId, isNull);
      expect(find.byType(ScanScreen), findsNothing);
    });

    testWidgets('errors that name no entry are said in general', (
      tester,
    ) async {
      await openReview(tester, ScanDraft(records: [rabiesShot()]));
      ai.applyError = validationProblem({
        'records[3].record.title': ['Too long.'],
        'keepPhotos': ['Not allowed.'],
      });

      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();

      expect(
        find.text("Some details weren't accepted. Check them and try again."),
        findsOneWidget,
      );
      expect(find.text('Check the highlighted fields.'), findsNothing);
      expect(find.byType(ScanScreen), findsOneWidget);
    });
  });

  group('a save whose answer is lost', () {
    testWidgets('saved after all: the review closes with what was saved', (
      tester,
    ) async {
      await openReview(tester, ScanDraft(records: [rabiesShot()]));
      ai.loseNextApplyResponse = true;

      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();

      expect(find.byType(ScanScreen), findsNothing);
      expect(
        snackText(tester),
        'Saved 1 record · 1 plan updated · photos added to the passport '
        'pages (saved before the connection dropped)',
      );
      expect(ai.applies, hasLength(1), reason: 'not sent again');
    });

    testWidgets('not saved: the review stays, and the next save sends what '
        'the user has then', (tester) async {
      await openReview(
        tester,
        ScanDraft(
          records: [
            rabiesShot(),
            DraftRecord(
              key: 1,
              kind: CareKind.deworming,
              title: 'Deworming',
              performedOn: DateTime(2025, 1, 5),
              selected: false,
            ),
          ],
        ),
      );
      ai.applyError = networkError;
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Can't reach the server. Check your connection and try again.",
        ),
        findsOneWidget,
      );
      expect(find.text('Check the scan'), findsOneWidget);

      ai.applyError = null;
      await tick(tester, 'record-1');
      await tester.tap(find.text('Save 2 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies.last.$2.records, hasLength(2));
      expect(find.byType(ScanScreen), findsNothing);
    });

    testWidgets('the pet can not be reloaded either: the review and its '
        'changes stay', (tester) async {
      await openReview(
        tester,
        ScanDraft(
          records: [
            rabiesShot(),
            DraftRecord(
              key: 1,
              kind: CareKind.deworming,
              title: 'Deworming',
              performedOn: DateTime(2025, 1, 5),
              selected: false,
            ),
          ],
        ),
      );
      await tick(tester, 'record-1');
      ai.applyError = networkError;
      pets.error = networkError;
      await tester.tap(find.text('Save 2 selected'));
      await tester.pumpAndSettle();

      expect(find.text('Check the scan'), findsOneWidget);
      expect(tickOf(tester, 'record-1').value, isTrue, reason: 'kept');

      ai.applyError = null;
      pets.error = null;
      await tester.tap(find.text('Save 2 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies.last.$2.records, hasLength(2));
      expect(find.byType(ScanScreen), findsNothing);
    });

    testWidgets("can't tell: the next save asks the server first", (
      tester,
    ) async {
      await openReview(tester, ScanDraft(records: [rabiesShot()]));
      ai
        ..loseNextApplyResponse = true
        ..getError = networkError;
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Couldn't tell whether it was saved. Check your connection and "
          'save again: nothing is saved twice.',
        ),
        findsOneWidget,
      );

      ai.getError = null;
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      expect(ai.applies, hasLength(1), reason: 'it was saved: not sent again');
      expect(find.byType(ScanScreen), findsNothing);
      expect(snackText(tester), contains('(saved before the connection'));
    });

    testWidgets('discarding a scan that was saved says so, not "discarded"', (
      tester,
    ) async {
      await openReview(tester, ScanDraft(records: [rabiesShot()]));
      ai
        ..loseNextApplyResponse = true
        ..getError = networkError;
      await tester.tap(find.text('Save 1 selected'));
      await tester.pumpAndSettle();
      ai.getError = null;

      await tester.tap(find.text('Discard scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(ai.scans['scan-1']!.status, ScanStatus.applied);
      expect(find.byType(ScanScreen), findsNothing);
      expect(snackText(tester), contains('(this scan was saved already)'));
      expect(find.text('Scan discarded'), findsNothing);
    });
  });

  testWidgets('leaving with changes asks first; the scan stays', (
    tester,
  ) async {
    await openReview(tester, ScanDraft(records: [rabiesShot()]));

    // No changes: back just goes back.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);

    await openReview(tester, ScanDraft(records: [rabiesShot()]));
    await tick(tester, 'record-0');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    expect(
      find.text(
        'Your changes here will be lost. The scan stays on the Passport tab '
        'to check later.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Check the scan'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(ai.scans['scan-1']!.status, ScanStatus.ready);
    expect(ai.discarded, isEmpty);
  });

  testWidgets('tapping the tab again asks before it drops changes made '
      'here, in the words of a scan', (tester) async {
    await openReview(tester, ScanDraft(records: [rabiesShot()]));
    await tick(tester, 'record-0');

    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    expect(
      find.text(
        'Your changes here will be lost. The scan stays on the Passport tab '
        'to check later.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Check the scan'), findsOneWidget);
    expect(tickOf(tester, 'record-0').value, isFalse, reason: 'kept');

    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(ai.scans['scan-1']!.status, ScanStatus.ready);
  });

  testWidgets('a save reloads every list it can change', (tester) async {
    await openReview(tester, ScanDraft(records: [rabiesShot()]));
    final app = container(tester);
    // Shown somewhere in the app: each list is loaded and watched.
    for (final provider in <ProviderListenable<Object?>>[
      carePlansProvider('p1'),
      careRecordsProvider('p1'),
      passportRecordsProvider('p1'),
      todayProvider,
      carePlanProvider(rabiesPlan.id),
      petProvider('p1'),
      petsProvider,
      passportProvider('p1'),
      petDocumentsProvider('p1'),
      petScansProvider('p1'),
      weightLogProvider('p1'),
    ]) {
      app.listen(provider, (_, _) {});
    }
    await tester.pumpAndSettle();
    int count() =>
        care.planListCalls +
        care.recordListCalls +
        care.passportRecordCalls +
        care.planCalls +
        today.calls +
        pets.petCalls +
        pets.calls +
        passport.getCalls +
        documents.listCalls +
        ai.listCalls +
        weight.listCalls;
    final before = (
      plans: care.planListCalls,
      records: care.recordListCalls,
      passportRecords: care.passportRecordCalls,
      plan: care.planCalls,
      today: today.calls,
      pet: pets.petCalls,
      pets: pets.calls,
      passport: passport.getCalls,
      documents: documents.listCalls,
      scans: ai.listCalls,
      weights: weight.listCalls,
    );
    expect(count(), greaterThan(0));

    await tester.tap(find.text('Save 1 selected'));
    await tester.pumpAndSettle();

    expect(care.planListCalls, greaterThan(before.plans), reason: 'plans');
    expect(
      care.recordListCalls,
      greaterThan(before.records),
      reason: 'history',
    );
    expect(
      care.passportRecordCalls,
      greaterThan(before.passportRecords),
      reason: 'passport sections',
    );
    expect(care.planCalls, greaterThan(before.plan), reason: 'an open plan');
    expect(today.calls, greaterThan(before.today), reason: 'Today');
    expect(pets.petCalls, greaterThan(before.pet), reason: 'chips');
    expect(pets.calls, greaterThan(before.pets), reason: 'the pet list');
    expect(
      passport.getCalls,
      greaterThan(before.passport),
      reason: 'passport header',
    );
    expect(
      documents.listCalls,
      greaterThan(before.documents),
      reason: 'passport pages',
    );
    expect(ai.listCalls, greaterThan(before.scans), reason: 'scans');
    expect(
      weight.listCalls,
      greaterThan(before.weights),
      reason: "a check-up's weight",
    );
  });
}
