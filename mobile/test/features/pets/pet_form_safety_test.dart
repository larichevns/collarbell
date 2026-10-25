// Regression tests for the pet form and the Overview photo: leaving during a
// save, fields out of view, rows that come and go, retries and colours this
// app doesn't know.
import 'dart:async';

import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pets_screen.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

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

/// A normal phone: the form is longer than the screen.
const phone = Size(390, 844);

void main() {
  late FakePetsRepository pets;
  late FakeFilesRepository files;
  late FakeMediaPicker picker;

  setUp(() {
    pets = FakePetsRepository();
    files = FakeFilesRepository();
    picker = FakeMediaPicker()
      ..library = const [PickedMedia(path: '/tmp/cat.jpg', name: 'cat.jpg')];
  });

  Future<void> open(WidgetTester tester, String location, {Size? size}) =>
      pumpApp(
        tester,
        location: location,
        size: size ?? phone,
        overrides: fakeRepositories(pets: pets, files: files, picker: picker),
      );

  Future<void> choosePhoto(WidgetTester tester) async {
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
  }

  /// The form scrolls as one page.
  Finder formScroll() => find.byType(Scrollable).first;

  testWidgets('the new-pet form stays open while saving; the list updates', (
    tester,
  ) async {
    await open(tester, '/pets');
    await tester.tap(find.text('Add pet'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'Murka');
    await choosePhoto(tester);

    files.gate = Completer<void>();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pageBack();
    // The spinner never settles, so time is pumped instead.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('New pet'), findsOneWidget, reason: 'not left');

    files.gate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(pets.photosSet, [('new-1', 'upload-1')]);
    expect(find.text('No pets yet'), findsNothing);
    expect(
      find.descendant(of: find.byType(PetRow), matching: find.byType(Image)),
      findsOneWidget,
      reason: 'the list shows the new pet with its photo',
    );
  });

  testWidgets('a photo changed on the Overview tab reaches the list, even '
      'when the user left the pet meanwhile', (tester) async {
    pets.pets = [const Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat)];
    await open(tester, '/pets/p1');

    files.gate = Completer<void>();
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    // The photo shows a spinner while it uploads; time is pumped instead
    // of waiting for it to settle.
    await tester.pump(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    files.gate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(pets.photosSet, [('p1', 'upload-1')]);
    expect(
      find.descendant(of: find.byType(PetRow), matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets('switching Neutered on keeps typed text in its own field', (
    tester,
  ) async {
    await open(tester, '/pets/new', size: const Size(390, 2600));
    await tester.enterText(field('Name'), 'Murka');
    await tester.enterText(field('Markings'), 'White socks');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).last); // Neutered
    await tester.pumpAndSettle();

    // The keyboard is still up; the user goes on typing.
    tester.testTextInput.enterText('White socks, star on chest');
    await tester.pumpAndSettle();

    expect(textOf(tester, 'Markings'), 'White socks, star on chest');
    expect(textOf(tester, 'Coat colour'), isEmpty);
  });

  testWidgets('a mistake out of view is checked, shown and scrolled to', (
    tester,
  ) async {
    await open(tester, '/pets/new');
    await tester.enterText(field('Name'), 'Murka');
    await tester.scrollUntilVisible(
      find.text('Add a microchip or tattoo'),
      300,
      scrollable: formScroll(),
    );
    await tester.tap(find.text('Add a microchip or tattoo'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Chip number'), '1234567890123'); // 13 digits
    // Back to the top to fix the name; the chip is out of view now.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'Murka Ginger');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(pets.created, isEmpty, reason: 'caught before sending');
    expect(
      find.text('An ISO microchip number has 15 digits').hitTestable(),
      findsOneWidget,
      reason: 'scrolled into view',
    );
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
  });

  testWidgets('a server error on a field out of view is scrolled to', (
    tester,
  ) async {
    pets.saveError = validationError({
      'identifiers[0].code': ['An ISO microchip number has 15 digits.'],
    });
    await open(tester, '/pets/new');
    await tester.enterText(field('Name'), 'Murka');
    await tester.scrollUntilVisible(
      find.text('Add a microchip or tattoo'),
      300,
      scrollable: formScroll(),
    );
    await tester.tap(find.text('Add a microchip or tattoo'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Chip number'), '276 098 100 123 456');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text("This value wasn't accepted. Check it.").hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
  });

  testWidgets('a retry after a failed save reuses the uploaded photo', (
    tester,
  ) async {
    await open(tester, '/pets/new');
    await tester.enterText(field('Name'), 'Murka');
    await choosePhoto(tester);

    pets.saveError = const ApiException(ApiErrorKind.network);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );

    pets.saveError = null;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(files.uploads, hasLength(1), reason: 'not uploaded twice');
    expect(pets.photosSet, [('new-1', 'upload-1')]);
  });
}
