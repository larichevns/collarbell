import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// The text field under the label [label].
Finder field(String label) => find.descendant(
  of: find.widgetWithText(CbTextField, label),
  matching: find.byType(TextFormField),
);

/// A phone tall enough to show the whole form without scrolling.
const tallPhone = Size(390, 2600);

ApiException validationError(Map<String, List<String>> errors) => ApiException(
  ApiErrorKind.validation,
  statusCode: 400,
  problem: ProblemDetails(
    status: 400,
    title: 'One or more validation errors occurred.',
    errors: errors,
  ),
);

void main() {
  late FakePetsRepository pets;
  late FakeFilesRepository files;
  late FakeMediaPicker picker;

  setUp(() {
    pets = FakePetsRepository();
    files = FakeFilesRepository();
    picker = FakeMediaPicker();
  });

  Future<void> openForm(WidgetTester tester, {String location = '/pets/new'}) {
    return pumpApp(
      tester,
      location: location,
      size: tallPhone,
      overrides: fakeRepositories(pets: pets, files: files, picker: picker),
    );
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  Future<void> addIdentifier(WidgetTester tester) async {
    await tester.tap(find.text('Add a microchip or tattoo'));
    await tester.pumpAndSettle();
  }

  testWidgets('checks the name and the chip numbers before saving', (
    tester,
  ) async {
    await openForm(tester);

    await save(tester);
    expect(find.text("Enter the pet's name"), findsOneWidget);

    await addIdentifier(tester);
    await tester.enterText(field('Chip number'), '123');
    await tester.pumpAndSettle();
    expect(find.text('An ISO microchip number has 15 digits'), findsOneWidget);

    await tester.enterText(field('Chip number'), '999 000 000 000 001');
    await tester.pumpAndSettle();
    expect(
      find.text('Numbers starting with 999 belong to test chips'),
      findsOneWidget,
    );

    // The same number twice, written differently.
    await tester.enterText(field('Chip number'), '276 098 100 123 456');
    await addIdentifier(tester);
    await tester.enterText(field('Chip number').last, '276-098-100-123-456');
    await tester.pumpAndSettle();
    expect(find.text('This number is already in the list'), findsOneWidget);

    // A non-ISO chip has its own format and the travel hint.
    await tester.tap(find.text('ISO microchip').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non-ISO microchip').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Use 10 characters 0–9 and A–F, or 9 digits (AVID)'),
      findsOneWidget,
    );
    await tester.enterText(field('Chip number').last, '0a1b2c3d4e');
    await tester.pumpAndSettle();
    expect(
      find.text('Not ISO: take your own scanner when travelling.'),
      findsOneWidget,
    );

    expect(pets.created, isEmpty);
  });

  testWidgets('saves a new pet and returns to the refreshed list', (
    tester,
  ) async {
    await openForm(tester);

    await tester.enterText(field('Name'), ' Murka ');
    await tester.tap(find.text('Female'));
    await tester.enterText(field('Breed'), 'British Shorthair');
    await addIdentifier(tester);
    await tester.enterText(field('Chip number'), '276 098 100 123 456');
    await tester.enterText(field('Location'), 'Left side of the neck');
    await save(tester);

    final input = pets.created.single;
    expect(input.name, 'Murka');
    expect(input.species, PetSpecies.cat);
    expect(input.sex, PetSex.female);
    expect(input.breed, 'British Shorthair');
    expect(input.neutered, isNull, reason: 'never answered');
    final chip = input.identifiers.single;
    expect(chip.type, IdentifierType.isoChip);
    expect(chip.code, '276098100123456');
    expect(chip.rawCode, '276 098 100 123 456');
    expect(chip.location, 'Left side of the neck');

    expect(find.text('New pet'), findsNothing);
    expect(find.text('Murka'), findsOneWidget);
    expect(pets.calls, 2, reason: 'the list reloads after saving');
  });

  testWidgets('shows server errors on their fields and the rest in a banner', (
    tester,
  ) async {
    await openForm(tester);
    await tester.enterText(field('Name'), 'Murka');
    await addIdentifier(tester);
    await tester.enterText(field('Chip number'), '276 098 100 123 456');

    pets.saveError = validationError({
      'name': ['Use 60 characters or fewer.'],
      'identifiers[0].code': ['An ISO microchip number has 15 digits.'],
    });
    await save(tester);
    expect(
      find.text("This value wasn't accepted. Check it."),
      findsNWidgets(2),
    );
    expect(
      find.text("Some details weren't accepted. Check them and try again."),
      findsNothing,
    );

    // A field the form doesn't have goes to the banner.
    pets.saveError = validationError({
      'species': ['Unknown species.'],
    });
    await save(tester);
    expect(find.text("This value wasn't accepted. Check it."), findsNothing);
    expect(
      find.text("Some details weren't accepted. Check them and try again."),
      findsOneWidget,
    );

    pets.saveError = const ApiException(ApiErrorKind.network);
    await save(tester);
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(pets.created, isEmpty);
  });

  testWidgets('uploads the chosen photo and attaches it to the new pet', (
    tester,
  ) async {
    picker.library = [
      const PickedMedia(path: '/photos/murka.jpg', name: 'murka.jpg'),
    ];
    await openForm(tester);

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
    expect(find.text('Change photo'), findsOneWidget);

    await tester.enterText(field('Name'), 'Murka');
    await save(tester);

    expect(files.uploads.single.name, 'murka.jpg');
    expect(pets.photosSet.single, ('new-1', 'upload-1'));
  });

  testWidgets('a refused photo keeps the form open with the reason', (
    tester,
  ) async {
    picker.library = [
      const PickedMedia(path: '/photos/huge.jpg', name: 'huge.jpg'),
    ];
    files.error = const ApiException(
      ApiErrorKind.payloadTooLarge,
      statusCode: 413,
    );
    await openForm(tester);
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'Murka');

    await save(tester);

    expect(
      find.text('This file is too large. Upload files up to 15 MB.'),
      findsOneWidget,
    );
    expect(pets.created, isEmpty, reason: 'nothing is saved yet');
  });

  testWidgets('edits a pet: fields start filled, unchanged parts are kept', (
    tester,
  ) async {
    pets.pets = [
      Pet(
        id: 'p1',
        name: 'Murka',
        species: PetSpecies.cat,
        sex: PetSex.female,
        neutered: false,
        identifiers: [
          PetIdentifier(
            id: 'i1',
            type: IdentifierType.isoChip,
            code: '276098100123456',
            rawCode: '276 098 100 123 456',
            readOn: DateTime(2025, 5, 1),
          ),
        ],
      ),
    ];
    await openForm(tester, location: '/pets/p1/edit');

    expect(find.text('Edit details'), findsWidgets);
    expect(find.text('276 098 100 123 456'), findsOneWidget);
    await tester.enterText(field('Name'), 'Murka Petrovna');
    await save(tester);

    final (id, input) = pets.updated.single;
    expect(id, 'p1');
    expect(input.name, 'Murka Petrovna');
    expect(input.neutered, isFalse);
    expect(input.identifiers.single.readOn, DateTime(2025, 5, 1));
  });

  testWidgets('a chip removed after a failed save is forgotten', (
    tester,
  ) async {
    await openForm(tester);
    await tester.enterText(field('Name'), 'Murka');
    await addIdentifier(tester);
    await tester.enterText(field('Chip number'), '999 000 000 000 001');
    await save(tester);
    expect(
      find.text('Numbers starting with 999 belong to test chips'),
      findsOneWidget,
    );

    // The form validates as you type now; removing the card must not
    // validate it once more.
    await tester.tap(find.byTooltip('Remove from the list'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await save(tester);

    expect(pets.created.single.identifiers, isEmpty);
  });
}
