// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pet_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PetResponse _$PetResponseFromJson(Map<String, dynamic> json) => PetResponse(
  id: json['id'] as String,
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
  coat: Coat.fromJson(json['coat']),
  allergies: json['allergies'] as String?,
  notes: json['notes'] as String?,
  status: PetStatus.fromJson(json['status']),
  photo: json['photo'] == null
      ? null
      : FileLink.fromJson(json['photo'] as Map<String, dynamic>),
  identifiers: (json['identifiers'] as List<dynamic>)
      .map((e) => PetIdentifierResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: const RequiredDateOnlyConverter().fromJson(
    json['createdAt'] as String,
  ),
  updatedAt: const RequiredDateOnlyConverter().fromJson(
    json['updatedAt'] as String,
  ),
);

Map<String, dynamic> _$PetResponseToJson(PetResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
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
      'coat': _$CoatEnumMap[instance.coat]!,
      'allergies': instance.allergies,
      'notes': instance.notes,
      'status': _$PetStatusEnumMap[instance.status]!,
      'photo': instance.photo?.toJson(),
      'identifiers': instance.identifiers.map((e) => e.toJson()).toList(),
      'createdAt': const RequiredDateOnlyConverter().toJson(instance.createdAt),
      'updatedAt': const RequiredDateOnlyConverter().toJson(instance.updatedAt),
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
