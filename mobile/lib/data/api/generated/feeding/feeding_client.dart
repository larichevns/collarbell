// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/complete_routine_request.dart';
import '../models/routine_completion_response.dart';
import '../models/routine_request.dart';
import '../models/routine_response.dart';

part 'feeding_client.g.dart';

@RestApi()
abstract class FeedingClient {
  factory FeedingClient(Dio dio, {String? baseUrl}) = _FeedingClient;

  /// The pet's feeding schedules, active ones first.
  @GET('/api/v1/pets/{petId}/routines')
  Future<List<RoutineResponse>> listPetRoutines({
    @Path('petId') required String petId,
  });

  /// Add a feeding schedule: times of day, days of the week, food and portion.
  @POST('/api/v1/pets/{petId}/routines')
  Future<RoutineResponse> createRoutine({
    @Path('petId') required String petId,
    @Body() required RoutineRequest body,
  });

  /// One feeding schedule.
  @GET('/api/v1/routines/{id}')
  Future<RoutineResponse> getRoutine({
    @Path('id') required String id,
  });

  /// Change a feeding schedule; its reminders follow.
  @PUT('/api/v1/routines/{id}')
  Future<RoutineResponse> updateRoutine({
    @Path('id') required String id,
    @Body() required RoutineRequest body,
  });

  /// Delete a feeding schedule and its marks.
  @DELETE('/api/v1/routines/{id}')
  Future<void> deleteRoutine({
    @Path('id') required String id,
  });

  /// "Fed" (or "skipped") for one feeding. 409 with who did it when someone else marked it first.
  @POST('/api/v1/routines/{id}/completions')
  Future<RoutineCompletionResponse> completeRoutine({
    @Path('id') required String id,
    @Body() required CompleteRoutineRequest body,
  });

  /// Take a mark back, e.g. the wrong pet was tapped.
  @DELETE('/api/v1/routines/{id}/completions/{completionId}')
  Future<void> undoRoutineCompletion({
    @Path('id') required String id,
    @Path('completionId') required String completionId,
  });
}
