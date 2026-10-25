// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identifier_reading.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IdentifierReading _$IdentifierReadingFromJson(Map<String, dynamic> json) =>
    IdentifierReading(
      type: IdentifierType.fromJson(json['type']),
      code: json['code'] as String,
      rawCode: json['rawCode'] as String,
      appliedOn: const DateOnlyConverter().fromJson(
        json['appliedOn'] as String?,
      ),
      location: json['location'] as String?,
      problem: json['problem'] as String?,
    );

Map<String, dynamic> _$IdentifierReadingToJson(IdentifierReading instance) =>
    <String, dynamic>{
      'type': _$IdentifierTypeEnumMap[instance.type]!,
      'code': instance.code,
      'rawCode': instance.rawCode,
      'appliedOn': const DateOnlyConverter().toJson(instance.appliedOn),
      'location': instance.location,
      'problem': instance.problem,
    };

const _$IdentifierTypeEnumMap = {
  IdentifierType.isoChip: 'IsoChip',
  IdentifierType.legacyChip: 'LegacyChip',
  IdentifierType.tattoo: 'Tattoo',
  IdentifierType.$unknown: r'$unknown',
};
