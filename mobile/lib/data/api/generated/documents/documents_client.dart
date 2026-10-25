// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/add_pages_request.dart';
import '../models/document_details_request.dart';
import '../models/document_request.dart';
import '../models/document_response.dart';
import '../models/document_type.dart';

part 'documents_client.g.dart';

@RestApi()
abstract class DocumentsClient {
  factory DocumentsClient(Dio dio, {String? baseUrl}) = _DocumentsClient;

  /// The pet's documents, newest first; optionally only one type, such as PassportPage.
  @GET('/api/v1/pets/{petId}/documents')
  Future<List<DocumentResponse>> listPetDocuments({
    @Path('petId') required String petId,
    @Query('type') DocumentType? type,
  });

  /// Create a document from uploaded files; the order of fileIds is the page order.
  @POST('/api/v1/pets/{petId}/documents')
  Future<DocumentResponse> createPetDocument({
    @Path('petId') required String petId,
    @Body() required DocumentRequest body,
  });

  /// One document with links to its pages.
  @GET('/api/v1/documents/{id}')
  Future<DocumentResponse> getDocument({
    @Path('id') required String id,
  });

  /// Change the document's type, title, date and notes. The pages stay as they are.
  @PUT('/api/v1/documents/{id}')
  Future<DocumentResponse> updateDocument({
    @Path('id') required String id,
    @Body() required DocumentDetailsRequest body,
  });

  /// Delete the document and its files.
  @DELETE('/api/v1/documents/{id}')
  Future<void> deleteDocument({
    @Path('id') required String id,
  });

  /// Add uploaded files as pages at the end of the document.
  @POST('/api/v1/documents/{id}/pages')
  Future<DocumentResponse> addDocumentPages({
    @Path('id') required String id,
    @Body() required AddPagesRequest body,
  });

  /// Delete one page and its file. Deleting the last page deletes the document.
  @DELETE('/api/v1/documents/{id}/pages/{fileId}')
  Future<void> removeDocumentPage({
    @Path('id') required String id,
    @Path('fileId') required String fileId,
  });
}
