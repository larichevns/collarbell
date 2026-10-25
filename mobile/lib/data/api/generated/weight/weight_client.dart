// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/weight_request.dart';
import '../models/weight_response.dart';

part 'weight_client.g.dart';

@RestApi()
abstract class WeightClient {
  factory WeightClient(Dio dio, {String? baseUrl}) = _WeightClient;

  /// The pet's weight log, newest first: its weighings and the weights noted in its care records.
  @GET('/api/v1/pets/{petId}/weights')
  Future<List<WeightResponse>> listPetWeights({
    @Path('petId') required String petId,
  });

  /// Add a weighing.
  @POST('/api/v1/pets/{petId}/weights')
  Future<WeightResponse> createWeight({
    @Path('petId') required String petId,
    @Body() required WeightRequest body,
  });

  /// One weighing.
  @GET('/api/v1/weights/{id}')
  Future<WeightResponse> getWeight({
    @Path('id') required String id,
  });

  /// Change a weighing.
  @PUT('/api/v1/weights/{id}')
  Future<WeightResponse> updateWeight({
    @Path('id') required String id,
    @Body() required WeightRequest body,
  });

  /// Delete a weighing.
  @DELETE('/api/v1/weights/{id}')
  Future<void> deleteWeight({
    @Path('id') required String id,
  });
}
