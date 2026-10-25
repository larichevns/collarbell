// The camera page both scanners share, with a stand-in for the phone's camera:
// chip numbers for the pet form (from the camera or a photo), product codes
// for supplies.
import 'dart:async';

import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/ai_repository.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/pets/chip_reader.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/supplies/barcode_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// The phone's camera: it sees a code when a test [show]s one, and finds
/// [photoCodes] in any photo.
class FakeCamera extends MobileScannerPlatform {
  final _codes = StreamController<BarcodeCapture>.broadcast();
  var running = false;
  var photoCodes = <Barcode>[];

  /// The photos it looked for codes in.
  final analyzed = <String>[];

  /// When set, looking at a photo takes until it completes.
  Completer<void>? photoGate;

  void show(String code, BarcodeFormat format) => showAll([(code, format)]);

  /// Several codes in one sighting.
  void showAll(List<(String, BarcodeFormat)> codes) => _codes.add(
    BarcodeCapture(
      barcodes: [
        for (final (code, format) in codes)
          Barcode(rawValue: code, format: format),
      ],
    ),
  );

  @override
  Stream<BarcodeCapture?> get barcodesStream => _codes.stream;

  @override
  Stream<TorchState> get torchStateStream =>
      Stream.value(TorchState.unavailable);

  @override
  Stream<double> get zoomScaleStateStream => Stream.value(1);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    running = true;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(1280, 720),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async => running = false;

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);

  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const [],
  }) async {
    analyzed.add(path);
    final gate = photoGate;
    if (gate != null) await gate.future;
    return BarcodeCapture(barcodes: photoCodes);
  }

  @override
  Future<void> dispose() async {}
}

/// What a scanner gave back, once it closed.
class Scanned<T> {
  T? value;
  var closed = false;
}

const _photo = PickedMedia(path: '/tmp/passport.jpg', name: 'passport.jpg');

void main() {
  late FakeCamera camera;
  late FakeMediaPicker picker;

  setUp(() {
    MobileScannerPlatform.instance = camera = FakeCamera();
    picker = FakeMediaPicker()..library = [_photo];
  });

  /// Opens the scanner [read] shows, from a button, as the forms do.
  Future<Scanned<T>> open<T>(
    WidgetTester tester,
    Future<T?> Function(BuildContext context) read,
  ) async {
    final scanned = Scanned<T>();
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => read(context).then((value) {
              scanned
                ..value = value
                ..closed = true;
            }),
            child: const Text('Open'),
          ),
        ),
      ),
      overrides: [
        aiStatusProvider.overrideWith(
          (ref) async => const AiStatus(configured: true, freeTier: true),
        ),
      ],
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return scanned;
  }

  Future<Scanned<ChipScan>> openChipScanner(WidgetTester tester) =>
      open(tester, CameraChipReader(picker).read);

  Future<void> fromLibrary(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('chipFromPhoto')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
  }

  testWidgets('a chip sticker closes the scanner with its number', (
    tester,
  ) async {
    final scanned = await openChipScanner(tester);
    expect(find.text('Point the camera at the chip sticker'), findsOneWidget);
    // Where such a photo goes, on Gemini's free tier.
    expect(
      find.textContaining("Gemini's free tier: only your own documents"),
      findsOneWidget,
    );

    camera.show('ISO 643094100000001', BarcodeFormat.code128);
    await tester.pumpAndSettle();

    expect(scanned.closed, isTrue);
    final chip = scanned.value! as ChipBarcode;
    expect((chip.type, chip.code), (IdentifierType.isoChip, '643094100000001'));
  });

  testWidgets("a product's barcode isn't a chip: a short word, scanning goes "
      'on', (tester) async {
    final scanned = await openChipScanner(tester);

    camera.show('4006381333931', BarcodeFormat.code128);
    await tester.pumpAndSettle();
    expect(find.text("That isn't a microchip number"), findsOneWidget);
    expect(scanned.closed, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Point the camera at the chip sticker'), findsOneWidget);

    camera.show('0A1B2C3D4E', BarcodeFormat.code39);
    await tester.pumpAndSettle();
    final chip = scanned.value! as ChipBarcode;
    expect((chip.type, chip.code), (IdentifierType.legacyChip, '0A1B2C3D4E'));
  });

  testWidgets('a photo: the phone finds the barcode in it, and the photo '
      "doesn't stay", (tester) async {
    camera.photoCodes = [
      const Barcode(rawValue: '643094100000001', format: BarcodeFormat.code128),
    ];
    final scanned = await openChipScanner(tester);

    await fromLibrary(tester);

    expect(camera.analyzed, [_photo.path]);
    expect((scanned.value! as ChipBarcode).code, '643094100000001');
    expect(picker.deleted, [_photo.path]);
  });

  testWidgets('a photo without a barcode goes back to the form for AI', (
    tester,
  ) async {
    final scanned = await openChipScanner(tester);

    await fromLibrary(tester);

    expect((scanned.value! as ChipPhoto).photo.path, _photo.path);
    expect(picker.deleted, isEmpty, reason: 'the form sends it to AI first');
  });

  testWidgets('the camera rests while a photo is chosen, and comes back when '
      'none is', (tester) async {
    final scanned = await openChipScanner(tester);

    await tester.tap(find.byKey(const ValueKey('chipFromPhoto')));
    await tester.pumpAndSettle();
    expect(camera.running, isFalse);
    // The sheet is closed without a choice.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(camera.running, isTrue);
    expect(scanned.closed, isFalse);
  });

  testWidgets('a code seen while the scanner closes goes nowhere', (
    tester,
  ) async {
    final scanned = await openChipScanner(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump(); // the page starts closing; the camera still sees
    camera.show('643094100000001', BarcodeFormat.code128);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect((scanned.closed, scanned.value), (true, null));
  });

  testWidgets('a photo looked at while the scanner closes goes nowhere and '
      "doesn't stay", (tester) async {
    camera.photoGate = Completer<void>();
    final scanned = await openChipScanner(tester);
    await tester.tap(find.byKey(const ValueKey('chipFromPhoto')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(camera.analyzed, [_photo.path]);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump(); // the page starts closing...
    camera.photoGate!.complete();
    await tester.pump(); // ...and the photo turns out to have no barcode
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect((scanned.closed, scanned.value), (true, null));
    expect(picker.deleted, [_photo.path]);
  });

  testWidgets('two different chips in sight: the user picks the one', (
    tester,
  ) async {
    final scanned = await openChipScanner(tester);

    camera.showAll([
      ('643094100000001', BarcodeFormat.code128),
      ('276098100123456', BarcodeFormat.code128),
    ]);
    await tester.pumpAndSettle();
    expect(
      find.text('Several chip numbers found. Which one is it?'),
      findsOneWidget,
    );
    expect(camera.running, isFalse);
    await tester.tap(find.text('276 098 100 123 456'));
    await tester.pumpAndSettle();

    expect((scanned.value! as ChipBarcode).code, '276098100123456');
  });

  testWidgets('supplies: of two codes in sight, the first is taken, as '
      'before', (tester) async {
    final scanned = await open(tester, const CameraBarcodeReader().read);

    camera.showAll([
      ('4006381333931', BarcodeFormat.ean13),
      ('3182550702423', BarcodeFormat.ean13),
    ]);
    await tester.pumpAndSettle();

    expect(scanned.value, '4006381333931');
  });

  testWidgets('supplies: a UPC-E closes the scanner with its UPC-A', (
    tester,
  ) async {
    final scanned = await open(tester, const CameraBarcodeReader().read);
    expect(
      find.text('Point the camera at the barcode on the package'),
      findsOneWidget,
    );

    camera.show('04252614', BarcodeFormat.upcE);
    await tester.pumpAndSettle();

    expect(scanned.value, '042100005264');
  });

  testWidgets('supplies: typed digits, with the camera resting meanwhile', (
    tester,
  ) async {
    final scanned = await open(tester, const CameraBarcodeReader().read);

    await tester.tap(find.byKey(const ValueKey('typeCode')));
    await tester.pumpAndSettle();
    expect(camera.running, isFalse);
    await tester.enterText(find.byKey(const ValueKey('code')), '4006381333931');
    await tester.pump();
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();

    expect(scanned.value, '4006381333931');
  });
}
