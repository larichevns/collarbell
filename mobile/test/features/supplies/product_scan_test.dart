// Adding an item by scanning: a barcode the databases know, one already in
// supplies, a code that isn't a product, and photos of a package read by AI
// (a medicine offers a treatment plan).
import 'dart:async';

import 'package:collarbell/app/router.dart';
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/notifications/push_registration.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/supplies/barcode_reader.dart';
import 'package:collarbell/features/supplies/supplies_repository.dart';
import 'package:collarbell/features/supplies/supply.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

Pet testPet(String id, String name) =>
    Pet(id: id, name: name, species: PetSpecies.cat, sex: PetSex.unknown);

const _aiReady = AiStatus(configured: true);

void main() {
  testWidgets('a barcode Open Pet Food Facts knows: the form, with where the '
      'details came from', (tester) async {
    final supplies = FakeSuppliesRepository();
    supplies.lookups['4006381333931'] = const ProductLookup(
      code: '4006381333931',
      product: ProductDetails(
        name: 'Sterilised 37',
        brand: 'Royal Canin',
        category: SupplyCategory.dryFood,
        unit: SupplyUnit.gram,
        packageSize: 2000,
        kcalPerKg: 3860,
      ),
      source: ProductSource.openPetFoodFacts,
    );
    await pumpApp(
      tester,
      location: AppRoutes.supplyScan(),
      overrides: fakeRepositories(
        supplies: supplies,
        barcodes: FakeBarcodeReader(['4006381333931']),
      ),
    );

    expect(find.textContaining('Open Pet Food Facts'), findsOneWidget);
    await tapVisible(tester, find.text('Save'));

    final (input, _) = supplies.created.single;
    expect(
      (input.name, input.brand, input.packageSize, input.kcalPerKg),
      ('Sterilised 37', 'Royal Canin', 2000.0, 3860),
    );
    expect(
      (input.barcode, input.dataSource),
      ('4006381333931', SupplyDataSource.openPetFoodFacts),
    );
  });

  testWidgets('a product Open Pet Food Facts knows without its size: the '
      'photos fill it in, and the details stay theirs', (tester) async {
    final picker = FakeMediaPicker()
      ..camera.add(const PickedMedia(path: '/tmp/back.jpg', name: 'back.jpg'));
    final supplies = FakeSuppliesRepository()
      ..scanResult = const ProductDraft(
        isPetProduct: true,
        name: 'Kitten',
        unit: SupplyUnit.gram,
        packageSize: 2000,
      );
    supplies.lookups['3182550702423'] = const ProductLookup(
      code: '3182550702423',
      product: ProductDetails(name: 'Kitten', brand: 'Royal Canin'),
      source: ProductSource.openPetFoodFacts,
    );
    await pumpApp(
      tester,
      location: AppRoutes.supplyScan(),
      overrides: fakeRepositories(
        supplies: supplies,
        picker: picker,
        ai: FakeAiRepository(status: _aiReady),
        barcodes: FakeBarcodeReader(['3182550702423']),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('takePhotos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('readPhotos')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Open Pet Food Facts'), findsOneWidget);
    expect(
      find.text('Read from photos of the package. Check the details.'),
      findsOneWidget,
    );
    await tapVisible(tester, find.text('Save'));
    final (input, _) = supplies.created.single;
    // Not "AI": the server keeps Open Pet Food Facts out of the catalog.
    expect(input.dataSource, SupplyDataSource.openPetFoodFacts);
    expect((input.brand, input.packageSize), ('Royal Canin', 2000.0));
  });

  testWidgets(
    'a medicine\'s DataMatrix: its batch and expiry go to the notes',
    (tester) async {
      final supplies = FakeSuppliesRepository();
      supplies.lookups['0104006381333931'] = ProductLookup(
        code: '4006381333931',
        batch: 'L-2209',
        expiresOn: DateTime(2027, 12, 31),
      );
      await pumpApp(
        tester,
        location: AppRoutes.supplyScan(),
        overrides: fakeRepositories(
          supplies: supplies,
          barcodes: FakeBarcodeReader(['0104006381333931']),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('fillByHand')));
      await tester.pumpAndSettle();

      expect(find.text('Batch L-2209 · expires Dec 31, 2027'), findsOneWidget);
    },
  );

  testWidgets('an item no longer bought: a purchase brings it back', (
    tester,
  ) async {
    final supplies = FakeSuppliesRepository(
      supplies: [testSupply('s1', 'Old food', active: false)],
    );
    supplies.lookups['4006381333931'] = const ProductLookup(
      code: '4006381333931',
      existing: ExistingSupply(id: 's1', name: 'Old food', active: false),
    );
    await pumpApp(
      tester,
      location: AppRoutes.supplyScan(),
      overrides: fakeRepositories(
        supplies: supplies,
        barcodes: FakeBarcodeReader(['4006381333931']),
      ),
    );

    expect(
      find.text(
        'You marked it as no longer bought: a purchase brings it back to '
        'supplies.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a barcode of an item in supplies: "Bought" right away', (
    tester,
  ) async {
    final supplies = FakeSuppliesRepository(
      supplies: [testSupply('s1', 'Royal Canin', remaining: 100)],
    );
    supplies.lookups['4006381333931'] = const ProductLookup(
      code: '4006381333931',
      existing: ExistingSupply(id: 's1', name: 'Royal Canin', active: true),
    );
    await pumpApp(
      tester,
      location: AppRoutes.supplyScan(),
      overrides: fakeRepositories(
        supplies: supplies,
        barcodes: FakeBarcodeReader(['4006381333931']),
      ),
    );

    expect(
      find.text('This product is in your supplies already'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('buyExisting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveStock')));
    await tester.pumpAndSettle();

    expect(supplies.added.single.$1, 's1');
    // The item's page.
    expect(find.text('Correct'), findsOneWidget);
  });

  testWidgets('a code that isn\'t a product: say so, scan again', (
    tester,
  ) async {
    final supplies = FakeSuppliesRepository()..notProducts.add('WIFI:x');
    final reader = FakeBarcodeReader(['WIFI:x']);
    await pumpApp(
      tester,
      location: AppRoutes.supplyScan(),
      overrides: fakeRepositories(supplies: supplies, barcodes: reader),
    );

    expect(
      find.text(
        "That isn't a product barcode. Scan the barcode on the package.",
      ),
      findsOneWidget,
    );
    reader.codes.add('4006381333931');
    await tester.tap(find.byKey(const ValueKey('retry')));
    await tester.pumpAndSettle();
    // Unknown everywhere, and no AI: typed by hand, with the barcode.
    expect(
      find.text('No product with this barcode was found.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('takePhotos')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('fillByHand')));
    await tester.pumpAndSettle();
    expect(find.text('4006381333931'), findsOneWidget);
  });

  testWidgets('"Try again" tapped twice opens one scanner', (tester) async {
    final supplies = FakeSuppliesRepository()..notProducts.add('WIFI:x');
    final reader = FakeBarcodeReader(['WIFI:x']);
    await pumpApp(
      tester,
      location: AppRoutes.supplyScan(),
      overrides: fakeRepositories(supplies: supplies, barcodes: reader),
    );

    reader.gate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('retry')));
    await tester.tap(find.byKey(const ValueKey('retry')), warnIfMissed: false);
    reader.gate!.complete();
    await tester.pumpAndSettle();

    expect(reader.reads, 2, reason: 'the first scan, and one again');
  });

  testWidgets('a medicine from photos: doses, how long a package lasts, and '
      'a treatment plan offered', (tester) async {
    final picker = FakeMediaPicker()
      ..camera.addAll(const [
        PickedMedia(path: '/tmp/front.jpg', name: 'front.jpg'),
        PickedMedia(path: '/tmp/back.jpg', name: 'back.jpg'),
      ]);
    final files = FakeFilesRepository();
    final supplies = FakeSuppliesRepository()
      ..scanResult = const ProductDraft(
        isPetProduct: true,
        name: 'Bravecto Spot-On',
        brand: 'MSD',
        category: SupplyCategory.medication,
        unit: SupplyUnit.dose,
        packageSize: 1,
        treatment: CareKind.fleaTick,
        protectionWeeks: 12,
        dosesInPackage: 1,
      );
    final care = FakeCareRepository();
    await pumpApp(
      tester,
      location: AppRoutes.supplyScan(photos: true),
      overrides: fakeRepositories(
        supplies: supplies,
        picker: picker,
        files: files,
        care: care,
        ai: FakeAiRepository(status: _aiReady),
        pets: FakePetsRepository([testPet('p1', 'Murka')]),
      ),
    );

    // The first photo is taken at once; one more, then read.
    await tester.tap(find.byKey(const ValueKey('addPhoto')));
    await tester.pumpAndSettle();
    expect(find.text('Photo 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('readPhotos')));
    await tester.pumpAndSettle();

    expect(files.uploads, hasLength(2));
    expect(supplies.scans.single.$1, ['upload-1', 'upload-2']);
    expect(
      find.text('Read from photos of the package. Check the details.'),
      findsOneWidget,
    );
    // One dose lasts 12 weeks.
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('manual')))
          .controller!
          .text,
      '84',
    );
    await tapVisible(tester, find.text('Save'));

    final (input, _) = supplies.created.single;
    expect(
      (input.category, input.unit, input.packageSize),
      (SupplyCategory.medication, SupplyUnit.dose, 1.0),
    );
    expect(input.manualDailyUsage, closeTo(1 / 84, 0.0001));
    expect(input.dataSource, SupplyDataSource.ai);
    // The photos left the phone's storage once read.
    expect(picker.deleted, hasLength(2));

    expect(find.text('Protects for 12 weeks'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('addPlan')));
    await tester.pumpAndSettle();
    // The plan form, for the only pet, every 12 weeks.
    expect(find.text('Bravecto Spot-On'), findsWidgets);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('interval')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '12',
    );
  });

  testWidgets('AI busy: say so, and the details can still be typed', (
    tester,
  ) async {
    final picker = FakeMediaPicker()
      ..camera.add(
        const PickedMedia(path: '/tmp/front.jpg', name: 'front.jpg'),
      );
    final supplies = FakeSuppliesRepository()
      ..scanResult = const ProductScanFailed(ProductScanProblem.busy);
    await pumpApp(
      tester,
      location: AppRoutes.supplyScan(photos: true),
      overrides: fakeRepositories(
        supplies: supplies,
        picker: picker,
        ai: FakeAiRepository(status: _aiReady),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('readPhotos')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'AI is busy right now. Try again in a minute, or fill it in by hand.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fillByHand')));
    await tester.pumpAndSettle();
    expect(find.text('New item'), findsOneWidget);
  });

  test('a push about a supply opens the item', () {
    expect(
      routeForPush({'kind': 'supply', 'supplyId': 's1'}),
      AppRoutes.supply('s1'),
    );
    // Several to buy: Today lists them.
    expect(routeForPush({'kind': 'supplies'}), AppRoutes.today);
  });

  test('a UPC-E is read as the UPC-A it stands for', () {
    expect(expandUpcE('04252614'), '042100005264');
    expect(expandUpcE('01234565'), '012345000065');
    expect(expandUpcE('4006381333931'), '4006381333931');
  });
}
