import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/documents/document.dart';
import 'package:collarbell/features/files/widgets/page_grid.dart';
import 'package:collarbell/features/files/widgets/stored_file_image.dart';
import 'package:collarbell/features/passport/passport.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/weight/weight_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

final murka = Pet(
  id: 'p1',
  name: 'Murka',
  species: PetSpecies.cat,
  breed: 'British Shorthair',
  sex: PetSex.female,
  birthDate: DateTime(2021, 4, 3),
  birthDateApproximate: true,
  neutered: true,
  neuteredOn: DateTime(2022, 6, 5),
  identifiers: [
    PetIdentifier(
      id: 'i1',
      type: IdentifierType.isoChip,
      code: '276098100123456',
      rawCode: '276098100123456',
      appliedOn: DateTime(2021, 6, 1),
      location: 'Left side of the neck',
    ),
  ],
);

/// Scrolls the Passport tab's list until [finder] is built and visible.
Future<void> scrollPassportTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find
          .descendant(
            of: find.byType(PassportTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  late FakePetsRepository pets;
  late FakePassportRepository passport;
  late FakeDocumentsRepository documents;
  late FakeWeightRepository weight;

  setUp(() {
    pets = FakePetsRepository([murka]);
    passport = FakePassportRepository();
    documents = FakeDocumentsRepository();
    weight = FakeWeightRepository();
  });

  Future<void> openPet(WidgetTester tester) => pumpApp(
    tester,
    location: '/pets/p1',
    overrides: fakeRepositories(
      pets: pets,
      passport: passport,
      documents: documents,
      weight: weight,
    ),
  );

  testWidgets('has the tabs Overview, Health, Passport, Documents, Feeding '
      'and Weight', (tester) async {
    await openPet(tester);

    expect(find.text('Murka'), findsOneWidget);
    for (final tab in [
      'Overview',
      'Health',
      'Passport',
      'Documents',
      'Feeding',
      'Weight',
    ]) {
      expect(find.text(tab), findsOneWidget);
    }

    // The Overview tab: the details that are filled in. No weight yet: no
    // row for it.
    expect(find.text('British Shorthair'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('About Apr 3, 2021'), findsOneWidget);
    expect(find.text('Yes, Jun 5, 2022'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.textContaining(' kg'), findsNothing);
  });

  testWidgets('the Overview shows the latest weight with its date', (
    tester,
  ) async {
    weight.weighings.addAll([
      testWeight('w1', on: DateTime(2026, 8, 5), kg: 4.1),
      testWeight('w2', on: DateTime(2026, 9, 5), kg: 4.235),
    ]);
    await openPet(tester);

    expect(find.text('4.235 kg on Sep 5, 2026'), findsOneWidget);
  });

  testWidgets("a weight that can't be loaded leaves the Overview as it is", (
    tester,
  ) async {
    weight.listError = const ApiException(ApiErrorKind.network);
    await openPet(tester);

    expect(find.text('British Shorthair'), findsOneWidget);
    expect(find.textContaining(' kg'), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a reload of the weight that fails takes the old weight off the '
      'Overview', (tester) async {
    weight.weighings.add(testWeight('w1', on: DateTime(2026, 8, 5), kg: 4.1));
    await openPet(tester);
    expect(find.text('4.1 kg on Aug 5, 2026'), findsOneWidget);

    // A weighing added on another phone; reading the log again fails. The
    // old answer would show a weight that isn't the latest any more.
    weight.weighings.add(testWeight('w2', on: DateTime(2026, 9, 5), kg: 4.4));
    weight.listError = const ApiException(ApiErrorKind.network);
    appContainer(tester).invalidate(weightLogProvider('p1'));
    await tester.pumpAndSettle();

    expect(find.textContaining(' kg'), findsNothing);
  });

  testWidgets('the Passport tab: disclaimer, header, chips and pages', (
    tester,
  ) async {
    passport.passport = Passport(
      model: PassportModel.eu2014,
      number: 'DE01234567',
      issuingCountry: 'DE',
      issuedOn: DateTime(2021, 7, 1),
      issuer: const PassportContact(name: 'Dr. Weber', phone: '+49 30 1234'),
      owners: const [PassportContact(name: 'Anna')],
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    documents.documents = [
      PetDocument(
        id: 'd1',
        petId: 'p1',
        type: DocumentType.passportPage,
        pages: [testFile('page-1'), testFile('page-2')],
        createdAt: DateTime.utc(2026, 10, 1),
      ),
    ];
    await openPet(tester);

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This digital copy is for your information. '
        'The paper passport stays the official document.',
      ),
      findsOneWidget,
    );
    expect(find.text('EU passport (2014 model)'), findsOneWidget);
    expect(find.text('DE01234567'), findsOneWidget);
    expect(find.text('Dr. Weber\n+49 30 1234'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);

    await scrollPassportTo(tester, find.text('276 098 100 123 456'));
    expect(find.text('276 098 100 123 456'), findsOneWidget);
    expect(
      find.text('Implanted Jun 1, 2021 · Left side of the neck'),
      findsOneWidget,
    );

    await scrollPassportTo(tester, find.byType(PageGrid));
    expect(find.byType(PageTile), findsNWidgets(2));
  });

  testWidgets('an empty passport invites to add details and pages', (
    tester,
  ) async {
    await openPet(tester);

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Add the passport number, the vet who issued it and the owners.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add details'), findsOneWidget);
    await scrollPassportTo(tester, find.text('Add pages'));
    expect(
      find.text(
        'Photograph the pages of the paper passport to keep a copy at hand.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('deletes the pet after confirming and returns to the list', (
    tester,
  ) async {
    await openPet(tester);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete pet'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Murka?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(pets.deleted, ['p1']);
    expect(find.text('No pets yet'), findsOneWidget);
  });

  testWidgets('cancelling the dialog keeps the pet', (tester) async {
    await openPet(tester);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete pet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(pets.deleted, isEmpty);
    expect(find.text('Overview'), findsOneWidget);
  });
}
