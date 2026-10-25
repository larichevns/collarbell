// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/identifier_scan_request.dart';
import '../models/identifier_scan_response.dart';
import '../models/pet_request.dart';
import '../models/pet_response.dart';
import '../models/set_pet_photo_request.dart';

part 'pets_client.g.dart';

@RestApi()
abstract class PetsClient {
  factory PetsClient(Dio dio, {String? baseUrl}) = _PetsClient;

  /// Pets of the signed-in user's household: active first, then by when they were added.
  @GET('/api/v1/pets')
  Future<List<PetResponse>> listPets();

  /// Add a pet.
  @POST('/api/v1/pets')
  Future<PetResponse> createPet({
    @Body() required PetRequest body,
  });

  /// One pet.
  @GET('/api/v1/pets/{id}')
  Future<PetResponse> getPet({
    @Path('id') required String id,
  });

  /// Replace the pet's details and identifiers.
  @PUT('/api/v1/pets/{id}')
  Future<PetResponse> updatePet({
    @Path('id') required String id,
    @Body() required PetRequest body,
  });

  /// Delete the pet with its passport, documents and files. This can't be undone.
  @DELETE('/api/v1/pets/{id}')
  Future<void> deletePet({
    @Path('id') required String id,
  });

  /// Use an uploaded photo as the pet's photo; the previous photo is deleted.
  @PUT('/api/v1/pets/{id}/photo')
  Future<PetResponse> setPetPhoto({
    @Path('id') required String id,
    @Body() required SetPetPhotoRequest body,
  });

  /// Delete the pet's photo.
  @DELETE('/api/v1/pets/{id}/photo')
  Future<void> removePetPhoto({
    @Path('id') required String id,
  });

  /// Read the microchip and tattoo numbers on photos of a passport page or a chip sticker with AI, to fill in the pet form; nothing is saved. Waits for the answer (up to a few minutes). 409 urn:collarbell:problem:ai-limit: not enough AI photos left this month; 409 without a type: AI isn't set up; 429: too many AI requests in a minute; 503: all models are busy.
  @POST('/api/v1/pets/identifiers/scan')
  Future<IdentifierScanResponse> scanPetIdentifiers({
    @Body() required IdentifierScanRequest body,
  });
}
