// Regression tests: adding passport pages must never drop pages, whatever
// the screen showed (the user switched tabs during the upload, or the
// refresh after an add failed).
import 'dart:async';

import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/documents/document.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/passport/passport_pages.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/shared/widgets/state_views.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

PetDocument passportScans(List<String> pageIds) => PetDocument(
  id: 'd1',
  petId: 'p1',
  type: DocumentType.passportPage,
  pages: [for (final id in pageIds) testFile(id)],
  createdAt: DateTime.utc(2026, 9, 1),
);

/// Fails the [failCall]-th list request from now on (1 = the next one).
class FlakyDocuments extends FakeDocumentsRepository {
  FlakyDocuments(super.documents);

  int? failCall;

  @override
  Future<List<PetDocument>> getDocuments(String petId) async {
    final call = failCall;
    if (call != null) {
      failCall = call - 1;
      if (call == 1) throw const ApiException(ApiErrorKind.network);
    }
    return super.getDocuments(petId);
  }
}

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

Future<void> addPagesFromLibrary(WidgetTester tester) async {
  await scrollPassportTo(tester, find.text('Add pages'));
  // Fully in view: not under the navigation bar.
  await tapVisible(tester, find.text('Add pages'));
  await tester.tap(find.text('Choose from library'));
}

void main() {
  testWidgets('switching tabs during an upload keeps every page', (
    tester,
  ) async {
    final documents = FakeDocumentsRepository([
      passportScans(['a']),
    ]);
    final files = FakeFilesRepository();
    final picker = FakeMediaPicker()
      ..library = const [PickedMedia(path: '/tmp/b.jpg', name: 'b.jpg')];
    await pumpApp(
      tester,
      location: '/pets/p1',
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        documents: documents,
        files: files,
        picker: picker,
      ),
    );
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();

    files.gate = Completer<void>();
    await addPagesFromLibrary(tester);
    await tester.pump();
    // While the page uploads, the user looks at the Documents tab.
    // The tab bar scrolls when the tabs don't fit (the test font is wide).
    // The upload's spinner never settles, so one frame brings the tab in.
    await tester.ensureVisible(find.text('Documents'));
    await tester.pump();
    await tester.tap(find.text('Documents'));
    // The Passport tab stays alive meanwhile, its spinner too: time is
    // pumped instead of waiting for everything to settle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    files.gate!.complete();
    files.gate = null;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(documents.pageIds('d1'), ['a', 'upload-1']);
    expect(
      find.textContaining('2 pages'),
      findsOneWidget,
      reason: 'the Documents tab shows the new page',
    );

    // Back on the Passport tab, one more page.
    picker.library = const [PickedMedia(path: '/tmp/c.jpg', name: 'c.jpg')];
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    await addPagesFromLibrary(tester);
    await tester.pumpAndSettle();

    expect(documents.pageIds('d1'), ['a', 'upload-1', 'upload-2']);
    expect(documents.pagesRemoved, isEmpty);
  });

  testWidgets('a failed refresh after adding pages loses nothing', (
    tester,
  ) async {
    final documents = FlakyDocuments([
      passportScans(['a']),
    ]);
    final picker = FakeMediaPicker()
      ..library = const [PickedMedia(path: '/tmp/b.jpg', name: 'b.jpg')];
    await pumpApp(
      tester,
      location: '/pets/p1',
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        documents: documents,
        picker: picker,
      ),
    );
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();

    // The add asks for the documents (call 1), then the grid refreshes
    // (call 2), and that refresh fails.
    documents.failCall = 2;
    await addPagesFromLibrary(tester);
    await tester.pumpAndSettle();
    expect(documents.pageIds('d1'), ['a', 'upload-1']);
    expect(find.byType(CbErrorState), findsOneWidget);

    // The user adds another page from the error state.
    picker.library = const [PickedMedia(path: '/tmp/c.jpg', name: 'c.jpg')];
    await addPagesFromLibrary(tester);
    await tester.pumpAndSettle();

    expect(documents.pageIds('d1'), ['a', 'upload-1', 'upload-2']);
    expect(documents.pagesRemoved, isEmpty);
    expect(find.byType(CbErrorState), findsNothing);
  });

  testWidgets('a failed upload keeps the pages: "Upload again" sends them', (
    tester,
  ) async {
    final documents = FakeDocumentsRepository([
      passportScans(['a']),
    ]);
    final files = FakeFilesRepository()
      ..error = const ApiException(ApiErrorKind.network);
    final picker = FakeMediaPicker()
      ..library = const [PickedMedia(path: '/tmp/b.jpg', name: 'b.jpg')];
    await pumpApp(
      tester,
      location: '/pets/p1',
      overrides: fakeRepositories(
        pets: FakePetsRepository([murka]),
        documents: documents,
        files: files,
        picker: picker,
      ),
    );
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();

    await addPagesFromLibrary(tester);
    await tester.pumpAndSettle();
    expect(documents.pageIds('d1'), ['a']);

    // The connection is back; the same page goes, nothing picked again.
    files.error = null;
    picker.library = const [];
    await scrollPassportTo(tester, find.text('Upload again'));
    await tapVisible(tester, find.text('Upload again'));
    await tester.pumpAndSettle();

    expect(files.uploads.map((m) => m.name), ['b.jpg']);
    expect(documents.pageIds('d1'), ['a', 'upload-1']);
    expect(find.text('Upload again'), findsNothing);
  });

  test(
    'adding pages again skips those already there (a lost answer)',
    () async {
      final documents = FakeDocumentsRepository([
        passportScans(['a', 'upload-1']),
      ]);

      await addPassportPages(
        documents,
        petId: 'p1',
        uploaded: [testFile('upload-1'), testFile('upload-2')],
      );

      expect(documents.pageIds('d1'), ['a', 'upload-1', 'upload-2']);
    },
  );
}
