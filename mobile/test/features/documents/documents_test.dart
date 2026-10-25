import 'package:collarbell/features/documents/document.dart';
import 'package:collarbell/features/documents/documents_tab.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/files/widgets/stored_file_image.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

Finder field(String label) => find.descendant(
  of: find.widgetWithText(CbTextField, label),
  matching: find.byType(TextFormField),
);

/// The second line of a document row: parts joined with " · ", each kept
/// on one line with non-breaking spaces.
String detailsLine(List<String> parts) =>
    [for (final part in parts) part.replaceAll(' ', '\u00A0')].join(' · ');

/// The row of the document titled [title].
Finder rowOf(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(DocumentRow));

void main() {
  late FakeDocumentsRepository documents;
  late FakeFilesRepository files;
  late FakeMediaPicker picker;

  setUp(() {
    documents = FakeDocumentsRepository();
    files = FakeFilesRepository();
    picker = FakeMediaPicker();
  });

  Future<void> open(
    WidgetTester tester,
    String location, {
    Size size = const Size(390, 844),
  }) => pumpApp(
    tester,
    location: location,
    size: size,
    overrides: fakeRepositories(
      pets: FakePetsRepository([murka]),
      documents: documents,
      files: files,
      picker: picker,
    ),
  );

  testWidgets('lists documents: title or type, date, pages and a preview', (
    tester,
  ) async {
    documents.documents = [
      PetDocument(
        id: 'd2',
        petId: 'p1',
        type: DocumentType.labResult,
        title: 'Blood test',
        documentDate: DateTime(2026, 9, 1),
        pages: [testFile('results', pdf: true)],
        createdAt: DateTime.utc(2026, 10, 1),
      ),
      PetDocument(
        id: 'd1',
        petId: 'p1',
        type: DocumentType.passportPage,
        pages: [testFile('page-1'), testFile('page-2')],
        createdAt: DateTime.utc(2026, 9, 30, 12),
      ),
    ];
    await open(tester, '/pets/p1');

    // The tab bar scrolls when the tabs don't fit (the test font is wide).
    await tapVisible(tester, find.text('Documents'));

    expect(find.text('Blood test'), findsOneWidget);
    expect(
      find.text(detailsLine(['Lab results', 'Sep 1, 2026', '1 page'])),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rowOf('Blood test'),
        matching: find.byIcon(Symbols.picture_as_pdf_rounded),
      ),
      findsOneWidget,
    );

    // No title: the type names the document.
    expect(find.text('Passport pages'), findsOneWidget);
    expect(
      find.text(detailsLine(['Sep 30, 2026', '2 pages'])),
      findsOneWidget,
      reason: 'the type is the title already',
    );
    expect(
      find.descendant(
        of: rowOf('Passport pages'),
        matching: find.byType(StoredFileImage),
      ),
      findsOneWidget,
    );
  });

  testWidgets('adds passport pages from the camera, one shot after another', (
    tester,
  ) async {
    picker.camera.addAll(const [
      PickedMedia(path: '/tmp/page-1.jpg', name: 'page-1.jpg'),
      PickedMedia(path: '/tmp/page-2.jpg', name: 'page-2.jpg'),
    ]);
    await open(tester, '/pets/p1');
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    final addPages = find.text('Add pages');
    await tester.scrollUntilVisible(
      addPages,
      300,
      scrollable: find
          .descendant(
            of: find.byType(PassportTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    // Fully in view: not under the navigation bar.
    await tapVisible(tester, addPages);
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.text('Page added'), findsOneWidget);
    await tester.tap(find.text('Add another page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(
      [for (final media in files.uploads) media.name],
      ['page-1.jpg', 'page-2.jpg'],
    );
    final (petId, details, fileIds) = documents.created.single;
    expect(petId, 'p1');
    expect(details.type, DocumentType.passportPage);
    expect(fileIds, ['upload-1', 'upload-2']);
    expect(find.byType(PageTile), findsNWidgets(2));
  });

  testWidgets('more pages go to the existing passport document', (
    tester,
  ) async {
    documents.documents = [
      PetDocument(
        id: 'd1',
        petId: 'p1',
        type: DocumentType.passportPage,
        pages: [testFile('page-1')],
        createdAt: DateTime.utc(2026, 9, 30),
      ),
    ];
    picker.library = const [
      PickedMedia(path: '/photos/a.jpg', name: 'a.jpg'),
      PickedMedia(path: '/photos/b.jpg', name: 'b.jpg'),
    ];
    await open(tester, '/pets/p1', size: const Size(390, 1600));
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add pages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();

    final (id, fileIds) = documents.pagesAdded.single;
    expect(id, 'd1');
    expect(fileIds, ['upload-1', 'upload-2']);
    expect(documents.pageIds('d1'), ['page-1', 'upload-1', 'upload-2']);
    expect(documents.created, isEmpty);
    expect(find.byType(PageTile), findsNWidgets(3));
  });

  testWidgets('adds a document: photos and a PDF, one page removed first', (
    tester,
  ) async {
    picker.library = const [
      PickedMedia(path: '/photos/a.jpg', name: 'a.jpg'),
      PickedMedia(path: '/photos/b.jpg', name: 'b.jpg'),
    ];
    picker.pdf = const PickedMedia(path: '/files/lab.pdf', name: 'lab.pdf');
    await open(tester, '/pets/p1/documents/new', size: const Size(390, 1600));

    await tester.tap(find.text('Other document'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab results').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('Title (optional)'), 'Blood test');

    await tester.tap(find.text('Add pages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add pages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a PDF file'));
    await tester.pumpAndSettle();
    expect(find.byType(PickedMediaTile), findsNWidgets(3));

    await tester.tap(find.byTooltip('Remove page 1'));
    await tester.pumpAndSettle();
    expect(find.byType(PickedMediaTile), findsNWidgets(2));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      [for (final media in files.uploads) media.name],
      ['b.jpg', 'lab.pdf'],
    );
    final (petId, details, fileIds) = documents.created.single;
    expect(petId, 'p1');
    expect(details.type, DocumentType.labResult);
    expect(details.title, 'Blood test');
    expect(fileIds, ['upload-1', 'upload-2']);
    expect(find.text('New document'), findsNothing, reason: 'form closed');
  });

  testWidgets('a document needs at least one page', (tester) async {
    await open(tester, '/pets/p1/documents/new');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Add at least one page'), findsOneWidget);
    expect(documents.created, isEmpty);
  });
}
