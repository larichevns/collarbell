// Android's back swipe closes only what is on top. A tab keeps its own
// navigator under the app's one, and the scanner and dialogs open in the
// app's one: the swipe used to pop the tab's screen hidden under them too,
// and closing them then left no page at all (a black screen).
import 'package:collarbell/app/router.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/pump.dart';

/// Opens a page over the whole app, as the real scanner does
/// (`showBarcodeScanner`), and gives what it closes with.
class _ScannerPage extends FakeBarcodeReader {
  @override
  Future<String?> read(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<String>(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Scanner')),
            body: const SizedBox.expand(),
          ),
        ),
      );
}

Future<void> _backGesture(
  WidgetTester tester,
  String method, [
  Object? arguments,
]) => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
  SystemChannels.backGesture.name,
  SystemChannels.backGesture.codec.encodeMethodCall(
    MethodCall(method, arguments),
  ),
  (_) {},
);

/// A back swipe from the left edge, as Android 14 and later send it.
Future<void> swipeBack(WidgetTester tester) async {
  const start = <String, Object?>{
    'touchOffset': <double>[4, 400],
    'progress': 0.0,
    'swipeEdge': 0,
  };
  await _backGesture(tester, 'startBackGesture', start);
  await tester.pump();
  await _backGesture(tester, 'updateBackGestureProgress', {
    ...start,
    'progress': 0.6,
  });
  await tester.pump();
  await _backGesture(tester, 'commitBackGesture');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('over the barcode scanner it closes the scanner only, back to '
      'Supplies', (tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.supplies,
      overrides: fakeRepositories(barcodes: _ScannerPage()),
    );
    // No supplies yet: scanning a barcode is a card on the empty list.
    final scan = find.byKey(const ValueKey('firstByBarcode'));
    await tester.tap(scan);
    await tester.pumpAndSettle();
    expect(find.text('Scanner'), findsOneWidget);

    await swipeBack(tester);

    expect(find.text('Scanner'), findsNothing);
    expect(find.byType(CloseButton), findsNothing);
    expect(scan, findsOneWidget);

    // And the next scan opens as usual.
    await tester.tap(scan);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(scan, findsOneWidget);
  });

  testWidgets('over a dialog it closes the dialog, not the screen under it', (
    tester,
  ) async {
    final pets = FakePetsRepository([
      const Pet(
        id: 'p1',
        name: 'Murka',
        species: PetSpecies.cat,
        sex: PetSex.female,
      ),
    ]);
    await pumpApp(
      tester,
      location: '/pets/p1',
      overrides: fakeRepositories(pets: pets),
    );
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete pet'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Murka?'), findsOneWidget);

    await swipeBack(tester);

    expect(find.text('Delete Murka?'), findsNothing);
    expect(find.text('Overview'), findsOneWidget);
    expect(pets.deleted, isEmpty);

    // The next swipe leaves the pet's page for the list.
    await swipeBack(tester);
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Murka'), findsOneWidget);
  });

  testWidgets("on a tab's first screen it leaves the screen in place", (
    tester,
  ) async {
    await pumpApp(tester, location: AppRoutes.supplies);

    await swipeBack(tester);

    expect(find.text('Add'), findsOneWidget);
  });
}
