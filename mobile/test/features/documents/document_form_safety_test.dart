// Regression tests: saving a document must never drop pages, must not be
// interrupted by leaving the form, and must not upload pages twice.
import 'dart:async';

import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/documents/document.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

Finder field(String label) => find.descendant(
  of: find.widgetWithText(CbTextField, label),
  matching: find.byType(TextFormField),
);

PetDocument bloodTest(List<String> pageIds) => PetDocument(
  id: 'd1',
  petId: 'p1',
  type: DocumentType.labResult,
  title: 'Blood test',
  pages: [for (final id in pageIds) testFile(id)],
  createdAt: DateTime.utc(2026, 9, 1),
);

void main() {
  late FakeDocumentsRepository documents;
  late FakeFilesRepository files;
  late FakeMediaPicker picker;

  setUp(() {
    documents = FakeDocumentsRepository([
      bloodTest(['a']),
    ]);
    files = FakeFilesRepository();
    picker = FakeMediaPicker()
      ..library = const [PickedMedia(path: '/tmp/b.jpg', name: 'b.jpg')];
  });

  Future<void> open(WidgetTester tester, String location) => pumpApp(
    tester,
    location: location,
    overrides: fakeRepositories(
      pets: FakePetsRepository([murka]),
      documents: documents,
      files: files,
      picker: picker,
    ),
  );

  Future<void> addPageFromLibrary(WidgetTester tester) async {
    await tapVisible(tester, find.text('Add pages'));
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
  }

  testWidgets('the form stays open while saving; the document updates', (
    tester,
  ) async {
    await open(tester, '/pets/p1/documents/d1');
    expect(find.text('1 page'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await addPageFromLibrary(tester);
    files.gate = Completer<void>();
    await tester.tap(find.text('Save'));
    await tester.pump();

    // A slow upload: the user tries to go back. (The spinner never
    // settles, so time is pumped instead.)
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Edit document'), findsOneWidget, reason: 'not left');

    files.gate!.complete();
    files.gate = null;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(documents.pageIds('d1'), ['a', 'upload-1']);
    expect(find.text('2 pages'), findsOneWidget, reason: 'the detail reloads');

    // Editing again changes only the details.
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Title (optional)'), 'Blood test 2026');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(documents.detailsUpdated.last.$2.title, 'Blood test 2026');
    expect(documents.pageIds('d1'), ['a', 'upload-1']);
    expect(documents.pagesRemoved, isEmpty);
  });

  testWidgets('a form opened from an old copy keeps pages added since', (
    tester,
  ) async {
    documents.documents = [
      bloodTest(['a', 'x']),
    ];
    await open(tester, '/pets/p1/documents/d1/edit');
    // Another phone adds a page while this form is open.
    await documents.addPages('d1', ['y']);

    // Here the user removes page "a" and adds one.
    await tester.tap(find.byTooltip('Remove page 1'));
    await tester.pumpAndSettle();
    await addPageFromLibrary(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(documents.pageIds('d1'), ['x', 'y', 'upload-1']);
    expect(documents.pagesRemoved, [('d1', 'a')]);
  });

  testWidgets('replacing every page adds the new ones before removing', (
    tester,
  ) async {
    await open(tester, '/pets/p1/documents/d1/edit');

    await tester.tap(find.byTooltip('Remove page 1'));
    await tester.pumpAndSettle();
    await addPageFromLibrary(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Removing "a" first would have deleted the whole document.
    expect(documents.pageIds('d1'), ['upload-1']);
  });

  testWidgets('a retry after a failed save reuses the uploaded pages', (
    tester,
  ) async {
    picker.library = const [
      PickedMedia(path: '/tmp/b.jpg', name: 'b.jpg'),
      PickedMedia(path: '/tmp/c.jpg', name: 'c.jpg'),
    ];
    await open(tester, '/pets/p1/documents/new');
    await addPageFromLibrary(tester);

    documents.createError = const ApiException(ApiErrorKind.network);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );

    documents.createError = null;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(files.uploads, hasLength(2), reason: 'nothing uploaded twice');
    expect(documents.created.single.$3, ['upload-1', 'upload-2']);
  });
}
