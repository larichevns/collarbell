// Scanning a microchip number into the pet form: a barcode fills it at once;
// a photo without one is read by AI, which finds one number, several to pick
// from, or none.
import 'dart:async';

import 'package:collarbell/app/app.dart';
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/ai_repository.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/pets/chip_reader.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// The text field under the label [label].
Finder field(String label) => find.descendant(
  of: find.widgetWithText(CbTextField, label),
  matching: find.byType(TextFormField),
);

String textOf(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(field(label)).controller!.text;

const _aiReady = AiStatus(configured: true);

/// A photo of the passport page, as the scanner hands it over when the phone
/// found no barcode in it.
const _page = PickedMedia(path: '/tmp/passport.jpg', name: 'passport.jpg');

void main() {
  late FakePetsRepository pets;
  late FakeFilesRepository files;
  late FakeMediaPicker picker;

  setUp(() {
    pets = FakePetsRepository();
    files = FakeFilesRepository();
    picker = FakeMediaPicker();
  });

  /// A new pet called Murka, with one empty microchip card.
  Future<void> openForm(
    WidgetTester tester,
    ChipScan scan, {
    AiStatus ai = _aiReady,
  }) async {
    await pumpApp(
      tester,
      location: '/pets/new',
      size: const Size(390, 2600),
      overrides: fakeRepositories(
        pets: pets,
        files: files,
        picker: picker,
        ai: FakeAiRepository(status: ai),
        chips: FakeChipReader([scan]),
      ),
    );
    await tester.enterText(field('Name'), 'Murka');
    await tester.tap(find.text('Add a microchip or tattoo'));
    await tester.pumpAndSettle();
  }

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Scan the number'));
    await tester.pumpAndSettle();
  }

  Future<PetIdentifier> saved(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    return pets.created.single.identifiers.single;
  }

  testWidgets('a scanned sticker fills in the ISO number', (tester) async {
    await openForm(
      tester,
      const ChipBarcode(IdentifierType.isoChip, '643094100000001'),
    );

    await scan(tester);

    expect(textOf(tester, 'Chip number'), '643094100000001');
    expect(pets.identifierScans, isEmpty, reason: 'a barcode needs no AI');
    final chip = await saved(tester);
    expect((chip.type, chip.code), (IdentifierType.isoChip, '643094100000001'));
  });

  testWidgets('a photo read by AI fills in the number and where the chip is', (
    tester,
  ) async {
    pets.identifierScanResult = const [
      IdentifierReading(
        type: IdentifierType.isoChip,
        code: '643094100000001',
        rawCode: '643 094 100 000 001',
        location: 'Between shoulder blades',
      ),
    ];
    await openForm(tester, const ChipPhoto(_page));

    await scan(tester);

    expect(files.uploads.single.path, _page.path);
    expect(pets.identifierScans.single, ['upload-1']);
    expect(picker.deleted, [
      _page.path,
    ], reason: "a passport page doesn't stay on the phone");
    expect(textOf(tester, 'Chip number'), '643 094 100 000 001');
    expect(textOf(tester, 'Location'), 'Between shoulder blades');
    expect(
      find.text('Read from the photo: check it against the passport.'),
      findsOneWidget,
    );
    final chip = await saved(tester);
    expect(
      (chip.type, chip.code, chip.rawCode, chip.location),
      (
        IdentifierType.isoChip,
        '643094100000001',
        '643 094 100 000 001',
        'Between shoulder blades',
      ),
    );
  });

  testWidgets('several numbers on the photo: the user picks one, and a place '
      'already typed stays', (tester) async {
    pets.identifierScanResult = [
      const IdentifierReading(
        type: IdentifierType.isoChip,
        code: '27609810012345',
        rawCode: '27609810012345',
        problem: 'An ISO microchip number has 15 digits.',
      ),
      IdentifierReading(
        type: IdentifierType.legacyChip,
        code: '0A1B2C3D4E',
        rawCode: '0A1B2C3D4E',
        appliedOn: DateTime(2019, 5, 2),
        location: 'Neck',
      ),
    ];
    await openForm(tester, const ChipPhoto(_page));
    await tester.enterText(field('Location'), 'Left side of the neck');

    await scan(tester);

    expect(
      find.text('Several numbers on the photo. Which one is it?'),
      findsOneWidget,
    );
    // A digit short: the app says so in its own words.
    expect(find.text('An ISO microchip number has 15 digits'), findsOneWidget);
    await tester.tap(find.text('0A1B2C3D4E'));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'Chip number'), '0A1B2C3D4E');
    final chip = await saved(tester);
    expect(
      (chip.type, chip.code, chip.appliedOn, chip.location),
      (
        IdentifierType.legacyChip,
        '0A1B2C3D4E',
        DateTime(2019, 5, 2),
        'Left side of the neck',
      ),
    );
  });

  testWidgets('Cancel while the photo uploads: nothing goes to AI, and the '
      'form stays when the upload ends as the dialog closes', (tester) async {
    files.gate = Completer<void>();
    await openForm(tester, const ChipPhoto(_page));
    await tester.tap(find.byTooltip('Scan the number'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Reading the photo'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump(); // the dialog starts closing...
    files.gate!.complete();
    await tester.pump(); // ...and the upload ends meanwhile
    await tester.pumpAndSettle();

    expect(find.text('New pet'), findsOneWidget);
    expect(pets.identifierScans, isEmpty);
    expect(picker.deleted, [_page.path]);
    expect(textOf(tester, 'Chip number'), isEmpty);
  });

  testWidgets('Cancel while AI reads: the reading is called off', (
    tester,
  ) async {
    pets.identifierScanGate = Completer<void>();
    pets.identifierScanResult = const [
      IdentifierReading(
        type: IdentifierType.isoChip,
        code: '643094100000001',
        rawCode: '643094100000001',
      ),
    ];
    await openForm(tester, const ChipPhoto(_page));
    await tester.tap(find.byTooltip('Scan the number'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pets.identifierScanTokens.single!.isCancelled, isTrue);
    pets.identifierScanGate!.complete();
    await tester.pumpAndSettle();

    expect(textOf(tester, 'Chip number'), isEmpty);
    expect(find.text('New pet'), findsOneWidget);
  });

  testWidgets('a scan that replaces another number brings its own place and '
      'date', (tester) async {
    pets.identifierScanResult = [
      IdentifierReading(
        type: IdentifierType.isoChip,
        code: '643094100000001',
        rawCode: '643094100000001',
        appliedOn: DateTime(2020, 1, 15),
        location: 'Between shoulder blades',
      ),
    ];
    await openForm(tester, const ChipPhoto(_page));
    // Typed earlier, for another chip.
    await tester.enterText(field('Chip number'), '276098100123456');
    await tester.enterText(field('Location'), 'Left side of the neck');

    await scan(tester);

    expect(textOf(tester, 'Chip number'), '643094100000001');
    final chip = await saved(tester);
    expect(
      (chip.code, chip.location, chip.appliedOn),
      ('643094100000001', 'Between shoulder blades', DateTime(2020, 1, 15)),
    );
  });

  testWidgets('a double tap opens one scanner', (tester) async {
    final chips = FakeChipReader([
      const ChipBarcode(IdentifierType.isoChip, '643094100000001'),
    ])..gate = Completer<void>();
    await pumpApp(
      tester,
      location: '/pets/new',
      size: const Size(390, 2600),
      overrides: fakeRepositories(pets: pets, chips: chips),
    );
    await tester.tap(find.text('Add a microchip or tattoo'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Scan the number'));
    await tester.tap(find.byTooltip('Scan the number'));
    chips.gate!.complete();
    await tester.pumpAndSettle();

    expect(chips.reads, 1);
    expect(textOf(tester, 'Chip number'), '643094100000001');
  });

  testWidgets('no number on the photo: say so, the field stays empty', (
    tester,
  ) async {
    await openForm(tester, const ChipPhoto(_page));

    await scan(tester);

    expect(
      find.text('No chip number found on the photo — type it in.'),
      findsOneWidget,
    );
    expect(textOf(tester, 'Chip number'), isEmpty);
    expect(picker.deleted, [_page.path]);
  });

  testWidgets('AI busy: say so, the number can still be typed', (tester) async {
    pets.identifierScanResult = const IdentifierScanFailed(
      IdentifierScanProblem.busy,
    );
    await openForm(tester, const ChipPhoto(_page));

    await scan(tester);

    const busy =
        'AI is busy right now. Try again in a minute, or type the number in.';
    expect(find.text(busy), findsOneWidget);
    expect(textOf(tester, 'Chip number'), isEmpty);

    // Typing the number puts the note away.
    await tester.enterText(field('Chip number'), '643094100000001');
    await tester.pumpAndSettle();
    expect(find.text(busy), findsNothing);
    expect((await saved(tester)).code, '643094100000001');
  });

  testWidgets('without AI on the server, the photo is not sent', (
    tester,
  ) async {
    await openForm(tester, const ChipPhoto(_page), ai: AiStatus.notConfigured);
    // Known by now: the scanner's page asks while it is open.
    ProviderScope.containerOf(
      tester.element(find.byType(CollarbellApp)),
    ).read(aiStatusProvider);
    await tester.pumpAndSettle();

    await scan(tester);

    expect(
      find.text(
        "No barcode on the photo, and AI isn't set up to read it: type the "
        'number in.',
      ),
      findsOneWidget,
    );
    expect(files.uploads, isEmpty);
    expect(picker.deleted, [_page.path]);
  });
}
