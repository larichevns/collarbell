// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pet_identifier_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PetIdentifierRequest _$PetIdentifierRequestFromJson(
  Map<String, dynamic> json,
) => PetIdentifierRequest(
  type: IdentifierType.fromJson(json['type']),
  code: json['code'] as String,
  appliedOn: const DateOnlyConverter().fromJson(json['appliedOn'] as String?),
  readOn: const DateOnlyConverter().fromJson(json['readOn'] as String?),
  location: json['location'] as String?,
);

Map<String, dynamic> _$PetIdentifierRequestToJson(
  PetIdentifierRequest instance,
) => <String, dynamic>{
  'type': _$IdentifierTypeEnumMap[instance.type]!,
  'code': instance.code,
  'appliedOn': const DateOnlyConverter().toJson(instance.appliedOn),
  'readOn': const DateOnlyConverter().toJson(instance.readOn),
  'location': instance.location,
};

const _$IdentifierTypeEnumMap = {
  IdentifierType.isoChip: 'IsoChip',
  IdentifierType.legacyChip: 'LegacyChip',
  IdentifierType.tattoo: 'Tattoo',
  IdentifierType.$unknown: r'$unknown',
};
