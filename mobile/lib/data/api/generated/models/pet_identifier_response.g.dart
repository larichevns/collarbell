// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pet_identifier_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PetIdentifierResponse _$PetIdentifierResponseFromJson(
  Map<String, dynamic> json,
) => PetIdentifierResponse(
  id: json['id'] as String,
  type: IdentifierType.fromJson(json['type']),
  code: json['code'] as String,
  rawCode: json['rawCode'] as String,
  appliedOn: const DateOnlyConverter().fromJson(json['appliedOn'] as String?),
  readOn: const DateOnlyConverter().fromJson(json['readOn'] as String?),
  location: json['location'] as String?,
);

Map<String, dynamic> _$PetIdentifierResponseToJson(
  PetIdentifierResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$IdentifierTypeEnumMap[instance.type]!,
  'code': instance.code,
  'rawCode': instance.rawCode,
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
