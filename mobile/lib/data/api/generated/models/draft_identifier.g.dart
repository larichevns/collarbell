// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_identifier.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DraftIdentifier _$DraftIdentifierFromJson(Map<String, dynamic> json) =>
    DraftIdentifier(
      key: (json['key'] as num).toInt(),
      type: IdentifierType.fromJson(json['type']),
      code: json['code'] as String?,
      appliedOn: const DateOnlyConverter().fromJson(
        json['appliedOn'] as String?,
      ),
      location: json['location'] as String?,
      evidence: json['evidence'] as String?,
      page: (json['page'] as num).toInt(),
      warnings: (json['warnings'] as List<dynamic>)
          .map((e) => DraftWarning.fromJson(e as Map<String, dynamic>))
          .toList(),
      selected: json['selected'] as bool,
    );

Map<String, dynamic> _$DraftIdentifierToJson(DraftIdentifier instance) =>
    <String, dynamic>{
      'key': instance.key,
      'type': _$IdentifierTypeEnumMap[instance.type]!,
      'code': instance.code,
      'appliedOn': const DateOnlyConverter().toJson(instance.appliedOn),
      'location': instance.location,
      'evidence': instance.evidence,
      'page': instance.page,
      'warnings': instance.warnings.map((e) => e.toJson()).toList(),
      'selected': instance.selected,
    };

const _$IdentifierTypeEnumMap = {
  IdentifierType.isoChip: 'IsoChip',
  IdentifierType.legacyChip: 'LegacyChip',
  IdentifierType.tattoo: 'Tattoo',
  IdentifierType.$unknown: r'$unknown',
};
