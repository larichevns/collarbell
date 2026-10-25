import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../files/files_repository.dart';
import '../me/profile_sync.dart';
import 'document.dart';

/// Documents of the household's pets. Every method throws ApiException.
///
/// There is no way to replace a document's page list: pages are added and
/// removed one by one, so a screen working from an old list can never drop
/// pages it doesn't know about.
abstract interface class DocumentsRepository {
  /// The pet's documents, newest first.
  Future<List<PetDocument>> getDocuments(String petId);

  Future<PetDocument> getDocument(String id);

  /// Creates a document whose pages are [fileIds] (uploaded files), in this
  /// order.
  Future<PetDocument> createDocument(
    String petId,
    DocumentDetails details,
    List<String> fileIds,
  );

  /// Changes the type, title, date and notes; the pages stay as they are.
  Future<PetDocument> updateDetails(String id, DocumentDetails details);

  /// Adds uploaded files as pages at the end of the document.
  Future<PetDocument> addPages(String id, List<String> fileIds);

  /// Deletes one page and its file. Deleting the last page deletes the whole
  /// document. A page that is already gone is not an error: a retry after a
  /// lost response must not get stuck.
  Future<void> removePage(String documentId, String fileId);

  /// Also deletes the document's files.
  Future<void> deleteDocument(String id);
}

/// [DocumentsRepository] over the generated API client.
class ApiDocumentsRepository implements DocumentsRepository {
  ApiDocumentsRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<PetDocument>> getDocuments(String petId) async {
    final documents = await _client.send(
      (api) => api.documents.listPetDocuments(petId: petId),
    );
    return [for (final document in documents) documentFromDto(document)];
  }

  @override
  Future<PetDocument> getDocument(String id) async => documentFromDto(
    await _client.send((api) => api.documents.getDocument(id: id)),
  );

  @override
  Future<PetDocument> createDocument(
    String petId,
    DocumentDetails details,
    List<String> fileIds,
  ) async {
    final request = dto.DocumentRequest(
      type: _typeToDto(details.type),
      title: details.title,
      documentDate: details.documentDate,
      notes: details.notes,
      fileIds: fileIds,
    );
    return documentFromDto(
      await _client.send(
        (api) => api.documents.createPetDocument(petId: petId, body: request),
      ),
    );
  }

  @override
  Future<PetDocument> updateDetails(String id, DocumentDetails details) async {
    final request = dto.DocumentDetailsRequest(
      type: _typeToDto(details.type),
      title: details.title,
      documentDate: details.documentDate,
      notes: details.notes,
    );
    return documentFromDto(
      await _client.send(
        (api) => api.documents.updateDocument(id: id, body: request),
      ),
    );
  }

  @override
  Future<PetDocument> addPages(String id, List<String> fileIds) async {
    final request = dto.AddPagesRequest(fileIds: fileIds);
    return documentFromDto(
      await _client.send(
        (api) => api.documents.addDocumentPages(id: id, body: request),
      ),
    );
  }

  @override
  Future<void> removePage(String documentId, String fileId) async {
    try {
      await _client.send(
        (api) =>
            api.documents.removeDocumentPage(id: documentId, fileId: fileId),
      );
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.notFound) rethrow;
    }
  }

  @override
  Future<void> deleteDocument(String id) =>
      _client.send((api) => api.documents.deleteDocument(id: id));

  static dto.DocumentType _typeToDto(DocumentType type) => switch (type) {
    DocumentType.passportPage => dto.DocumentType.passportPage,
    DocumentType.vaccinationCertificate =>
      dto.DocumentType.vaccinationCertificate,
    DocumentType.labResult => dto.DocumentType.labResult,
    DocumentType.prescription => dto.DocumentType.prescription,
    DocumentType.invoice => dto.DocumentType.invoice,
    DocumentType.insurance => dto.DocumentType.insurance,
    DocumentType.other => dto.DocumentType.other,
  };
}

/// Maps the API representation. A document type the app doesn't know yet is
/// shown as "other".
PetDocument documentFromDto(dto.DocumentResponse document) => PetDocument(
  id: document.id,
  petId: document.petId,
  type: switch (document.type) {
    dto.DocumentType.passportPage => DocumentType.passportPage,
    dto.DocumentType.vaccinationCertificate =>
      DocumentType.vaccinationCertificate,
    dto.DocumentType.labResult => DocumentType.labResult,
    dto.DocumentType.prescription => DocumentType.prescription,
    dto.DocumentType.invoice => DocumentType.invoice,
    dto.DocumentType.insurance => DocumentType.insurance,
    dto.DocumentType.other || dto.DocumentType.$unknown => DocumentType.other,
  },
  title: document.title,
  documentDate: document.documentDate == null
      ? null
      : DateTime(
          document.documentDate!.year,
          document.documentDate!.month,
          document.documentDate!.day,
        ),
  notes: document.notes,
  pages: [for (final page in document.pages) storedFileFromDto(page)],
  createdAt: document.createdAt,
);

final documentsRepositoryProvider = Provider<DocumentsRepository>(
  (ref) => ApiDocumentsRepository(ref.watch(apiClientProvider)),
);

/// All documents of one pet, newest first. The Passport tab shows the pages
/// of its `passportPage` documents; the Documents tab shows them all.
final petDocumentsProvider = FutureProvider.autoDispose
    .family<List<PetDocument>, String>((ref, petId) async {
      final repository = ref.watch(documentsRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getDocuments(petId);
    });

/// One document, for its detail screen.
final documentProvider = FutureProvider.autoDispose.family<PetDocument, String>(
  (ref, id) async {
    final repository = ref.watch(documentsRepositoryProvider);
    await ref.watch(profileSyncProvider.future);
    return repository.getDocument(id);
  },
);
