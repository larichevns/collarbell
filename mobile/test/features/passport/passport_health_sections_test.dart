// The passport's health sections V–X: compact rows built from the records,
// an empty line for empty sections, and "Add" with the section's kind.
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/shared/widgets/cb_section.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

/// Scrolls the Passport tab until [finder] is built and on screen.
Future<void> scrollPassportTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find
        .descendant(
          of: find.byType(PassportTab),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  late FakeCareRepository care;

  setUp(() => care = FakeCareRepository());

  Future<void> openPassport(WidgetTester tester) => pumpApp(
    tester,
    location: '/pets/p1?tab=passport',
    overrides: fakeRepositories(pets: FakePetsRepository([murka]), care: care),
  );

  testWidgets('each section lists its records, oldest first', (tester) async {
    care.records = [
      testRecord(
        'deworm',
        kind: CareKind.deworming,
        title: 'Deworming',
        performedOn: DateTime(2026, 7, 6),
        product: 'Milbemax',
      ),
      testRecord(
        'travel',
        kind: CareKind.echinococcus,
        title: 'Tapeworm treatment',
        performedOn: DateTime(2026, 6, 1),
        product: 'Milbemax',
      ),
      testRecord(
        'fvrcp',
        title: 'FVRCP',
        targets: const [VaccineTarget.fpv, VaccineTarget.fhv1],
        performedOn: DateTime(2026, 2, 1),
        product: 'Purevax RCP',
      ),
      testRecord(
        'titer',
        kind: CareKind.rabiesTiter,
        title: 'Rabies antibody test',
        performedOn: DateTime(2025, 6, 1),
        details: const CareRecordDetails(
          laboratory: 'BioLab',
          titerIuPerMl: 2.5,
        ),
      ),
      testRecord(
        'rabies-2',
        title: 'Rabies',
        targets: const [VaccineTarget.rabies],
        performedOn: DateTime(2026, 3, 1),
        product: 'Nobivac Rabies',
        batchNumber: 'B456',
      ),
      testRecord(
        'rabies-1',
        title: 'Rabies',
        targets: const [VaccineTarget.rabies],
        performedOn: DateTime(2025, 3, 1),
        product: 'Nobivac Rabies',
        batchNumber: 'A123',
        validFrom: DateTime(2025, 3, 22),
        validUntil: DateTime(2028, 2, 28),
      ),
    ];
    await openPassport(tester);

    await scrollPassportTo(tester, find.text('V. Rabies vaccination'));
    expect(find.text('Nobivac Rabies · Batch A123'), findsOneWidget);
    expect(find.text('Valid Mar 22, 2025 – Feb 28, 2028'), findsOneWidget);
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(
      top(find.text('Mar 1, 2025')),
      lessThan(top(find.text('Mar 1, 2026'))),
      reason: 'oldest first, as in the paper passport',
    );

    await scrollPassportTo(tester, find.text('VI. Rabies antibody test'));
    expect(find.text('2.5 IU/ml · BioLab'), findsOneWidget);

    await scrollPassportTo(tester, find.text('VII. Echinococcus treatment'));
    expect(find.text('Jun 1, 2026'), findsOneWidget);

    await scrollPassportTo(
      tester,
      find.text('VIII. Other parasite treatments'),
    );
    expect(find.text('Deworming · Milbemax'), findsOneWidget);

    await scrollPassportTo(tester, find.text('IX. Other vaccinations'));
    expect(find.text('Purevax RCP'), findsOneWidget);

    await scrollPassportTo(tester, find.text('X. Clinical examination'));
    expect(find.text('No entries yet.'), findsOneWidget);

    // A row opens its record.
    await tester.tap(find.text('Purevax RCP'));
    await tester.pumpAndSettle();
    expect(
      find.text('Panleukopenia (FPV), Herpesvirus (FHV-1)'),
      findsOneWidget,
    );
  });

  testWidgets('"Add" in the rabies section starts a rabies vaccination', (
    tester,
  ) async {
    await openPassport(tester);

    await scrollPassportTo(tester, find.text('V. Rabies vaccination'));
    expect(find.text('No entries yet.'), findsWidgets);
    final add = find.descendant(
      of: find
          .ancestor(
            of: find.text('V. Rabies vaccination'),
            matching: find.byType(CbSection),
          )
          .first,
      matching: find.byTooltip('Add'),
    );
    await tapVisible(tester, add);

    expect(find.text('New record'), findsOneWidget);
    final title = find.descendant(
      of: find.widgetWithText(CbTextField, 'Title'),
      matching: find.byType(TextFormField),
    );
    expect(tester.widget<TextFormField>(title).controller!.text, 'Rabies');
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Rabies'))
          .selected,
      isTrue,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(care.createdRecords.single.$2.targets, [VaccineTarget.rabies]);
    // Back on the passport, the section shows it.
    await scrollPassportTo(tester, find.text('V. Rabies vaccination'));
    expect(find.text('Rabies'), findsWidgets);
    expect(find.text('No entries yet.'), findsNWidgets(5));
  });
}
