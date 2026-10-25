import 'package:collarbell/features/documents/document.dart';
import 'package:collarbell/features/passport/passport_pages.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

PetDocument doc(
  String id,
  DocumentType type,
  List<String> pageIds, {
  String? title,
}) => PetDocument(
  id: id,
  petId: 'p1',
  type: type,
  title: title,
  pages: [for (final pageId in pageIds) testFile(pageId)],
  createdAt: DateTime.utc(2026, 10, 1),
);

void main() {
  test('pages come from passport-page documents only, oldest first', () {
    // The API sends the newest document first.
    final documents = [
      doc('d3', DocumentType.passportPage, ['c']),
      doc('d2', DocumentType.labResult, ['x']),
      doc('d1', DocumentType.passportPage, ['a', 'b']),
    ];

    expect(
      [for (final page in passportPages(documents)) page.id],
      ['a', 'b', 'c'],
    );
    expect(passportPageOwners(documents), {'a': 'd1', 'b': 'd1', 'c': 'd3'});
  });

  test('new pages start a passport-page document when there is none', () async {
    final repository = FakeDocumentsRepository();

    await addPassportPages(
      repository,
      petId: 'p1',
      uploaded: [testFile('n1'), testFile('n2')],
    );

    final (petId, details, fileIds) = repository.created.single;
    expect(petId, 'p1');
    expect(details.type, DocumentType.passportPage);
    expect(fileIds, ['n1', 'n2']);
  });

  test('new pages are appended to the newest passport document', () async {
    final repository = FakeDocumentsRepository([
      doc('d2', DocumentType.passportPage, ['c'], title: 'Scans'),
      doc('d1', DocumentType.passportPage, ['a']),
    ]);

    await addPassportPages(repository, petId: 'p1', uploaded: [testFile('n1')]);

    final (id, fileIds) = repository.pagesAdded.single;
    expect(id, 'd2');
    expect(fileIds, ['n1']);
    expect(repository.pageIds('d2'), ['c', 'n1']);
    expect(repository.documents.first.title, 'Scans');
    expect(repository.created, isEmpty);
  });

  test('the target document comes from the server, not an old list', () async {
    // The screen still shows no passport document, but one was created
    // meanwhile (an earlier add whose refresh failed).
    final repository = FakeDocumentsRepository([
      doc('d1', DocumentType.passportPage, ['a']),
    ]);

    await addPassportPages(repository, petId: 'p1', uploaded: [testFile('b')]);

    expect(repository.created, isEmpty, reason: 'no second document');
    expect(repository.pageIds('d1'), ['a', 'b']);
  });
}
