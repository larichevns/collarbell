// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/passport_records_response.dart';
import '../models/passport_request.dart';
import '../models/passport_response.dart';

part 'passport_client.g.dart';

@RestApi()
abstract class PassportClient {
  factory PassportClient(Dio dio, {String? baseUrl}) = _PassportClient;

  /// The header of the pet's digital passport copy (empty until saved).
  @GET('/api/v1/pets/{id}/passport')
  Future<PassportResponse> getPetPassport({
    @Path('id') required String id,
  });

  /// Save the passport header: model, number, country, issue date, issuing vet, owners.
  @PUT('/api/v1/pets/{id}/passport')
  Future<PassportResponse> updatePetPassport({
    @Path('id') required String id,
    @Body() required PassportRequest body,
  });

  /// The health sections of the digital passport copy (V–X), built from the care records.
  @GET('/api/v1/pets/{petId}/passport/records')
  Future<PassportRecordsResponse> getPetPassportRecords({
    @Path('petId') required String petId,
  });
}
