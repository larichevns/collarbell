import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../me/profile_sync.dart';
import 'passport.dart';

abstract interface class PassportRepository {
  /// The passport header; empty ([Passport.isSaved] false) until saved.
  /// Throws ApiException.
  Future<Passport> getPassport(String petId);

  /// Replaces the header. Contacts without any filled field are dropped by
  /// the server. Throws ApiException.
  Future<Passport> savePassport(String petId, Passport passport);
}

/// [PassportRepository] over the generated API client.
class ApiPassportRepository implements PassportRepository {
  ApiPassportRepository(this._client);

  final ApiClient _client;

  @override
  Future<Passport> getPassport(String petId) async => passportFromDto(
    await _client.send((api) => api.passport.getPetPassport(id: petId)),
  );

  @override
  Future<Passport> savePassport(String petId, Passport passport) async {
    final request = dto.PassportRequest(
      model: switch (passport.model) {
        null => null,
        PassportModel.eu2014 => dto.PassportModel.eu2014,
        PassportModel.eu2026 => dto.PassportModel.eu2026,
        PassportModel.other => dto.PassportModel.other,
      },
      passportNumber: passport.number,
      issuingCountry: passport.issuingCountry,
      issuedOn: passport.issuedOn,
      issuer: passport.issuer == null ? null : _contactToDto(passport.issuer!),
      owners: [for (final owner in passport.owners) _contactToDto(owner)],
      notes: passport.notes,
    );
    return passportFromDto(
      await _client.send(
        (api) => api.passport.updatePetPassport(id: petId, body: request),
      ),
    );
  }
}

/// Maps the API representation. A passport model the app doesn't know yet
/// is shown as "other".
Passport passportFromDto(dto.PassportResponse passport) => Passport(
  model: switch (passport.model) {
    null || dto.PassportModel.valueNull => null,
    dto.PassportModel.eu2014 => PassportModel.eu2014,
    dto.PassportModel.eu2026 => PassportModel.eu2026,
    dto.PassportModel.other ||
    dto.PassportModel.$unknown => PassportModel.other,
  },
  number: passport.passportNumber,
  issuingCountry: passport.issuingCountry,
  issuedOn: passport.issuedOn == null
      ? null
      : DateTime(
          passport.issuedOn!.year,
          passport.issuedOn!.month,
          passport.issuedOn!.day,
        ),
  issuer: passport.issuer == null ? null : _contactFromDto(passport.issuer!),
  owners: [for (final owner in passport.owners) _contactFromDto(owner)],
  notes: passport.notes,
  updatedAt: passport.updatedAt,
);

PassportContact _contactFromDto(dto.PassportContactDto contact) =>
    PassportContact(
      name: contact.name,
      address: contact.address,
      phone: contact.phone,
      email: contact.email,
    );

dto.PassportContactDto _contactToDto(PassportContact contact) =>
    dto.PassportContactDto(
      name: contact.name,
      address: contact.address,
      phone: contact.phone,
      email: contact.email,
    );

final passportRepositoryProvider = Provider<PassportRepository>(
  (ref) => ApiPassportRepository(ref.watch(apiClientProvider)),
);

/// The passport header of one pet.
final passportProvider = FutureProvider.autoDispose.family<Passport, String>((
  ref,
  petId,
) async {
  final repository = ref.watch(passportRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getPassport(petId);
});
