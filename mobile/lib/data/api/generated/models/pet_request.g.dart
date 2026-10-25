// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pet_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PetRequest _$PetRequestFromJson(Map<String, dynamic> json) => PetRequest(
  name: json['name'] as String,
  species: Species.fromJson(json['species']),
  breed: json['breed'] as String?,
  sex: Sex.fromJson(json['sex']),
  birthDate: const DateOnlyConverter().fromJson(json['birthDate'] as String?),
  birthDateApproximate: json['birthDateApproximate'] as bool,
  neutered: json['neutered'] as bool?,
  neuteredOn: const DateOnlyConverter().fromJson(json['neuteredOn'] as String?),
  color: json['color'] as String?,
  markings: json['markings'] as String?,
  coat: json['coat'] == null ? null : Coat.fromJson(json['coat']),
  allergies: json['allergies'] as String?,
  notes: json['notes'] as String?,
  status: json['status'] == null ? null : PetStatus.fromJson(json['status']),
  identifiers: (json['identifiers'] as List<dynamic>?)
      ?.map((e) => PetIdentifierRequest.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PetRequestToJson(PetRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'species': _$SpeciesEnumMap[instance.species]!,
      'breed': instance.breed,
      'sex': _$SexEnumMap[instance.sex]!,
      'birthDate': const DateOnlyConverter().toJson(instance.birthDate),
      'birthDateApproximate': instance.birthDateApproximate,
      'neutered': instance.neutered,
      'neuteredOn': const DateOnlyConverter().toJson(instance.neuteredOn),
      'color': instance.color,
      'markings': instance.markings,
      'coat': _$CoatEnumMap[instance.coat],
      'allergies': instance.allergies,
      'notes': instance.notes,
      'status': _$PetStatusEnumMap[instance.status],
      'identifiers': instance.identifiers?.map((e) => e.toJson()).toList(),
    };

const _$SpeciesEnumMap = {
  Species.cat: 'Cat',
  Species.dog: 'Dog',
  Species.other: 'Other',
  Species.$unknown: r'$unknown',
};

const _$SexEnumMap = {
  Sex.unknown: 'Unknown',
  Sex.male: 'Male',
  Sex.female: 'Female',
  Sex.$unknown: r'$unknown',
};

const _$CoatEnumMap = {
  Coat.smoke: 'Smoke',
  Coat.ginger: 'Ginger',
  Coat.fawn: 'Fawn',
  Coat.cocoa: 'Cocoa',
  Coat.lilac: 'Lilac',
  Coat.ink: 'Ink',
  Coat.$unknown: r'$unknown',
};

const _$PetStatusEnumMap = {
  PetStatus.active: 'Active',
  PetStatus.archived: 'Archived',
  PetStatus.deceased: 'Deceased',
  PetStatus.$unknown: r'$unknown',
};
