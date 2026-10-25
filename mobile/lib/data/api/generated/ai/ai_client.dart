// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/ai_import_response.dart';
import '../models/ai_status_response.dart';
import '../models/ai_test_response.dart';
import '../models/apply_import_request.dart';
import '../models/apply_import_response.dart';
import '../models/create_ai_import_request.dart';

part 'ai_client.g.dart';

@RestApi()
abstract class AiClient {
  factory AiClient(Dio dio, {String? baseUrl}) = _AiClient;

  /// The pet's scans still waiting for the user (being read, ready to check, or failed), newest first, to pick one up again. notes=true: notes only; notes=false: photo scans only; each kind has its own newest 20.
  @GET('/api/v1/pets/{petId}/ai-imports')
  Future<List<AiImportResponse>> listPetAiImports({
    @Path('petId') required String petId,
    @Query('notes') bool? notes,
  });

  /// Which AI models read photos, whether they are set up, and this month's use by the household.
  @GET('/api/v1/ai/status')
  Future<AiStatusResponse> getAiStatus();

  /// Check that a model answers and can see a picture. The picture counts as one of the month's AI photos; 409 urn:collarbell:problem:ai-limit: none left; 429: too many AI requests in a minute.
  @POST('/api/v1/ai/test')
  Future<AiTestResponse> testAi();

  /// Start reading uploaded photos of the passport (or a vet document), or a note, with AI. Poll the import until it is Ready. 409 urn:collarbell:problem:ai-limit: not enough AI photos left this month; 409 without a type: AI isn't set up; 429: too many AI requests in a minute, or with urn:collarbell:problem:text-limit too many notes today.
  @POST('/api/v1/ai-imports')
  Future<AiImportResponse> createAiImport({
    @Body() required CreateAiImportRequest body,
  });

  /// The scan's status, photos and draft.
  @GET('/api/v1/ai-imports/{id}')
  Future<AiImportResponse> getAiImport({
    @Path('id') required String id,
  });

  /// Throw the scan away; its photos are deleted with other unused uploads after a day. A saved scan can't be thrown away (409): what it saved stays.
  @DELETE('/api/v1/ai-imports/{id}')
  Future<void> discardAiImport({
    @Path('id') required String id,
  });

  /// Save what the user checked: records, weighings, identifiers, passport fields, and the photos as scans.
  @POST('/api/v1/ai-imports/{id}/apply')
  Future<ApplyImportResponse> applyAiImport({
    @Path('id') required String id,
    @Body() required ApplyImportRequest body,
  });
}
