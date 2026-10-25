import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../files/files_repository.dart';
import '../me/profile_sync.dart';
import 'pet.dart';

/// Why AI couldn't read the numbers on a photo.
enum IdentifierScanProblem {
  /// No AI model is set up on the server.
  notConfigured,

  /// All models are busy or out of quota: try again later.
  busy,

  /// The provider refused the request.
  rejected,
}

class IdentifierScanFailed implements Exception {
  const IdentifierScanFailed(this.problem);

  final IdentifierScanProblem problem;

  @override
  String toString() => 'IdentifierScanFailed($problem)';
}

/// The pets of the current household. Every method throws ApiException on
/// failure; a pet of another household is "not found".
abstract interface class PetsRepository {
  /// Active pets first, then archived and deceased ones.
  Future<List<Pet>> getPets();

  Future<Pet> getPet(String id);

  Future<Pet> createPet(PetInput input);

  /// Replaces the details and identifiers.
  Future<Pet> updatePet(String id, PetInput input);

  /// Also deletes the pet's passport, documents and files.
  Future<void> deletePet(String id);

  /// Uses an uploaded photo as the pet's photo; the old one is deleted.
  Future<Pet> setPhoto(String petId, String fileId);

  Future<void> removePhoto(String petId);

  /// Reads the microchip and tattoo numbers on uploaded photos of a passport
  /// page or a chip sticker with AI; nothing is saved. Waits for the answer
  /// (up to a few minutes); cancelling [cancelToken] stops the reading.
  /// Throws [IdentifierScanFailed] when AI can't read them now.
  Future<List<IdentifierReading>> scanIdentifiers(
    List<String> fileIds, {
    CancelToken? cancelToken,
  });
}

/// [PetsRepository] over the generated API client.
class ApiPetsRepository implements PetsRepository {
  ApiPetsRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Pet>> getPets() async {
    final pets = await _client.send((api) => api.pets.listPets());
    return [for (final pet in pets) petFromDto(pet)];
  }

  @override
  Future<Pet> getPet(String id) async =>
      petFromDto(await _client.send((api) => api.pets.getPet(id: id)));

  @override
  Future<Pet> createPet(PetInput input) async {
    final request = petRequestFromInput(input);
    return petFromDto(
      await _client.send((api) => api.pets.createPet(body: request)),
    );
  }

  @override
  Future<Pet> updatePet(String id, PetInput input) async {
    final request = petRequestFromInput(input);
    return petFromDto(
      await _client.send((api) => api.pets.updatePet(id: id, body: request)),
    );
  }

  @override
  Future<void> deletePet(String id) =>
      _client.send((api) => api.pets.deletePet(id: id));

  @override
  Future<Pet> setPhoto(String petId, String fileId) async {
    final request = dto.SetPetPhotoRequest(fileId: fileId);
    return petFromDto(
      await _client.send(
        (api) => api.pets.setPetPhoto(id: petId, body: request),
      ),
    );
  }

  @override
  Future<void> removePhoto(String petId) =>
      _client.send((api) => api.pets.removePetPhoto(id: petId));

  @override
  Future<List<IdentifierReading>> scanIdentifiers(
    List<String> fileIds, {
    CancelToken? cancelToken,
  }) async {
    final dto.IdentifierScanResponse read;
    try {
      read = await _client.send(
        (api) => api.pets.scanPetIdentifiers(
          body: dto.IdentifierScanRequest(fileIds: fileIds),
        ),
        cancelToken: cancelToken,
      );
    } on ApiException catch (error) {
      // The month's AI photos are a 409 too, of their own type: the form
      // says how many are left.
      if (error.problemType == ProblemTypes.aiLimit) rethrow;
      final problem = switch (error.statusCode) {
        409 => IdentifierScanProblem.notConfigured,
        502 => IdentifierScanProblem.rejected,
        503 => IdentifierScanProblem.busy,
        _ => null,
      };
      if (problem != null) throw IdentifierScanFailed(problem);
      rethrow;
    }
    return [
      for (final reading in read.identifiers)
        IdentifierReading(
          type: _identifierTypeFromDto(reading.type),
          code: reading.code,
          rawCode: reading.rawCode,
          appliedOn: _calendarDate(reading.appliedOn),
          location: reading.location,
          problem: reading.problem,
        ),
    ];
  }
}

/// Maps the API representation. Enum values the app doesn't know yet (from
/// a newer server) are shown as a default, so older apps keep working.
///
/// Saving the pet form sends what the form shows. What survives a save:
/// the status and the API's `coat` colour (the form sends neither). What
/// doesn't: an unknown species, sex or identifier type is saved as the
/// default shown, because the API requires those fields.
Pet petFromDto(dto.PetResponse pet) => Pet(
  id: pet.id,
  name: pet.name,
  species: switch (pet.species) {
    dto.Species.cat => PetSpecies.cat,
    dto.Species.dog => PetSpecies.dog,
    dto.Species.other || dto.Species.$unknown => PetSpecies.other,
  },
  breed: pet.breed,
  sex: switch (pet.sex) {
    dto.Sex.male => PetSex.male,
    dto.Sex.female => PetSex.female,
    dto.Sex.unknown || dto.Sex.$unknown => PetSex.unknown,
  },
  birthDate: _calendarDate(pet.birthDate),
  birthDateApproximate: pet.birthDateApproximate,
  neutered: pet.neutered,
  neuteredOn: _calendarDate(pet.neuteredOn),
  color: pet.color,
  markings: pet.markings,
  allergies: pet.allergies,
  notes: pet.notes,
  status: switch (pet.status) {
    dto.PetStatus.archived => PetStatus.archived,
    dto.PetStatus.deceased => PetStatus.deceased,
    dto.PetStatus.active || dto.PetStatus.$unknown => PetStatus.active,
  },
  photo: pet.photo == null ? null : storedFileFromDto(pet.photo!),
  identifiers: [
    for (final identifier in pet.identifiers)
      PetIdentifier(
        id: identifier.id,
        type: _identifierTypeFromDto(identifier.type),
        code: identifier.code,
        rawCode: identifier.rawCode,
        appliedOn: _calendarDate(identifier.appliedOn),
        readOn: _calendarDate(identifier.readOn),
        location: identifier.location,
      ),
  ],
);

/// The request body for create and update. Identifiers are sent as typed
/// ([PetIdentifier.rawCode]); the server normalises them itself.
dto.PetRequest petRequestFromInput(PetInput input) => dto.PetRequest(
  name: input.name,
  species: switch (input.species) {
    PetSpecies.cat => dto.Species.cat,
    PetSpecies.dog => dto.Species.dog,
    PetSpecies.other => dto.Species.other,
  },
  breed: input.breed,
  sex: switch (input.sex) {
    PetSex.male => dto.Sex.male,
    PetSex.female => dto.Sex.female,
    PetSex.unknown => dto.Sex.unknown,
  },
  birthDate: input.birthDate,
  birthDateApproximate: input.birthDateApproximate,
  neutered: input.neutered,
  neuteredOn: input.neuteredOn,
  color: input.color,
  markings: input.markings,
  // The app no longer shows the API's identity colour: null keeps the
  // current one (and lets the server pick one for a new pet).
  coat: null,
  allergies: input.allergies,
  notes: input.notes,
  // The form has no status field: null keeps the current status (and makes
  // new pets active).
  status: null,
  identifiers: [
    for (final identifier in input.identifiers)
      petIdentifierRequestFrom(identifier),
  ],
);

/// One microchip or tattoo as the pet form and the scan send it: the code
/// as typed ([PetIdentifier.rawCode]); the server normalises it itself.
dto.PetIdentifierRequest petIdentifierRequestFrom(PetIdentifier identifier) =>
    dto.PetIdentifierRequest(
      type: switch (identifier.type) {
        IdentifierType.isoChip => dto.IdentifierType.isoChip,
        IdentifierType.legacyChip => dto.IdentifierType.legacyChip,
        IdentifierType.tattoo => dto.IdentifierType.tattoo,
      },
      code: identifier.rawCode,
      appliedOn: identifier.appliedOn,
      readOn: identifier.readOn,
      location: identifier.location,
    );

IdentifierType _identifierTypeFromDto(dto.IdentifierType type) =>
    switch (type) {
      dto.IdentifierType.isoChip => IdentifierType.isoChip,
      dto.IdentifierType.legacyChip => IdentifierType.legacyChip,
      dto.IdentifierType.tattoo ||
      dto.IdentifierType.$unknown => IdentifierType.tattoo,
    };

/// Drops any time part: the API's dates are calendar dates.
DateTime? _calendarDate(DateTime? date) =>
    date == null ? null : DateTime(date.year, date.month, date.day);

final petsRepositoryProvider = Provider<PetsRepository>(
  (ref) => ApiPetsRepository(ref.watch(apiClientProvider)),
);

/// The household's pets. Waits for the profile sync of the current session,
/// so the very first request after sign-in is `PUT /api/v1/me`. Disposed on
/// sign-out (the tabs leave the tree), so the next account starts fresh.
final petsProvider = FutureProvider.autoDispose<List<Pet>>((ref) async {
  final repository = ref.watch(petsRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getPets();
});

/// One pet, for its detail screen.
final petProvider = FutureProvider.autoDispose.family<Pet, String>((
  ref,
  id,
) async {
  final repository = ref.watch(petsRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getPet(id);
});
