// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/add_record_files_request.dart';
import '../models/care_kind.dart';
import '../models/care_plan_request.dart';
import '../models/care_plan_response.dart';
import '../models/care_preset_response.dart';
import '../models/care_record_request.dart';
import '../models/care_record_response.dart';
import '../models/complete_care_plan_request.dart';
import '../models/complete_care_plan_response.dart';
import '../models/species.dart';

part 'care_client.g.dart';

@RestApi()
abstract class CareClient {
  factory CareClient(Dio dio, {String? baseUrl}) = _CareClient;

  /// Ready-made plans with default intervals; with species, only the ones that suit it.
  @GET('/api/v1/care-plan-presets')
  Future<List<CarePresetResponse>> listCarePlanPresets({
    @Query('species') Species? species,
  });

  /// The pet's plans with their status: active first, soonest due first.
  @GET('/api/v1/pets/{petId}/care-plans')
  Future<List<CarePlanResponse>> listPetCarePlans({
    @Path('petId') required String petId,
  });

  /// Add a plan, from a preset or your own.
  @POST('/api/v1/pets/{petId}/care-plans')
  Future<CarePlanResponse> createCarePlan({
    @Path('petId') required String petId,
    @Body() required CarePlanRequest body,
  });

  /// One plan.
  @GET('/api/v1/care-plans/{id}')
  Future<CarePlanResponse> getCarePlan({
    @Path('id') required String id,
  });

  /// Change a plan, including its next date.
  @PUT('/api/v1/care-plans/{id}')
  Future<CarePlanResponse> updateCarePlan({
    @Path('id') required String id,
    @Body() required CarePlanRequest body,
  });

  /// Delete a plan. The records it created stay in the history.
  @DELETE('/api/v1/care-plans/{id}')
  Future<void> deleteCarePlan({
    @Path('id') required String id,
  });

  /// "Done": add a record and move the plan to its next date (a one-off plan finishes).
  @POST('/api/v1/care-plans/{id}/complete')
  Future<CompleteCarePlanResponse> completeCarePlan({
    @Path('id') required String id,
    @Body() required CompleteCarePlanRequest body,
  });

  /// The pet's care history, newest first; optionally one kind only.
  @GET('/api/v1/pets/{petId}/care-records')
  Future<List<CareRecordResponse>> listPetCareRecords({
    @Path('petId') required String petId,
    @Query('kind') CareKind? kind,
  });

  /// Add a record by hand, for example from the paper passport.
  @POST('/api/v1/pets/{petId}/care-records')
  Future<CareRecordResponse> createCareRecord({
    @Path('petId') required String petId,
    @Body() required CareRecordRequest body,
  });

  /// One record.
  @GET('/api/v1/care-records/{id}')
  Future<CareRecordResponse> getCareRecord({
    @Path('id') required String id,
  });

  /// Change a record. Its photos stay as they are.
  @PUT('/api/v1/care-records/{id}')
  Future<CareRecordResponse> updateCareRecord({
    @Path('id') required String id,
    @Body() required CareRecordRequest body,
  });

  /// Delete a record and its photos. A plan it completed keeps its date.
  @DELETE('/api/v1/care-records/{id}')
  Future<void> deleteCareRecord({
    @Path('id') required String id,
  });

  /// Attach uploaded files (the vaccine sticker, the vet's conclusion).
  @POST('/api/v1/care-records/{id}/files')
  Future<CareRecordResponse> addCareRecordFiles({
    @Path('id') required String id,
    @Body() required AddRecordFilesRequest body,
  });

  /// Delete one attached file.
  @DELETE('/api/v1/care-records/{id}/files/{fileId}')
  Future<void> removeCareRecordFile({
    @Path('id') required String id,
    @Path('fileId') required String fileId,
  });
}
