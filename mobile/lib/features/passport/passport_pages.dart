/// The photographed pages of the paper passport are the pages of the pet's
/// `passportPage` documents. Usually there is one such document; the
/// Documents tab can create more.
library;

import '../documents/document.dart';
import '../documents/documents_repository.dart';
import '../files/stored_file.dart';

/// The pet's passport-page documents, oldest first, from [documents] in the
/// API's newest-first order. Showing them oldest first keeps added pages at
/// the end of the grid.
List<PetDocument> passportPageDocuments(List<PetDocument> documents) => [
  for (final document in documents.reversed)
    if (document.type == DocumentType.passportPage) document,
];

/// All passport pages in the order the grid shows them.
List<StoredFile> passportPages(List<PetDocument> documents) => [
  for (final document in passportPageDocuments(documents)) ...document.pages,
];

/// The document each passport page belongs to, by the page's file id, so
/// one page can be deleted on its own.
Map<String, String> passportPageOwners(List<PetDocument> documents) => {
  for (final document in passportPageDocuments(documents))
    for (final page in document.pages) page.id: document.id,
};

/// Adds uploaded pages at the end of the newest passport-page document, or
/// starts one when the pet has none.
///
/// It asks the server for the pet's documents first instead of trusting the
/// list on screen, which can be old (the user switched tabs during the
/// upload, or the last refresh failed). Pages already there are skipped: a
/// retry after a lost answer adds nothing twice.
Future<void> addPassportPages(
  DocumentsRepository repository, {
  required String petId,
  required List<StoredFile> uploaded,
}) async {
  final current = passportPageDocuments(await repository.getDocuments(petId));
  final there = passportPageOwners(current);
  final fileIds = [
    for (final file in uploaded)
      if (!there.containsKey(file.id)) file.id,
  ];
  if (fileIds.isEmpty) return;
  if (current.isEmpty) {
    await repository.createDocument(
      petId,
      const DocumentDetails(type: DocumentType.passportPage),
      fileIds,
    );
  } else {
    await repository.addPages(current.last.id, fileIds);
  }
}
