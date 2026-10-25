// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_weight.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DraftWeight _$DraftWeightFromJson(Map<String, dynamic> json) => DraftWeight(
  key: (json['key'] as num).toInt(),
  measuredOn: const DateOnlyConverter().fromJson(json['measuredOn'] as String?),
  weightKg: (json['weightKg'] as num?)?.toDouble(),
  evidence: json['evidence'] as String?,
  page: (json['page'] as num).toInt(),
  warnings: (json['warnings'] as List<dynamic>)
      .map((e) => DraftWarning.fromJson(e as Map<String, dynamic>))
      .toList(),
  duplicateOf: json['duplicateOf'] as String?,
  selected: json['selected'] as bool,
);

Map<String, dynamic> _$DraftWeightToJson(DraftWeight instance) =>
    <String, dynamic>{
      'key': instance.key,
      'measuredOn': const DateOnlyConverter().toJson(instance.measuredOn),
      'weightKg': instance.weightKg,
      'evidence': instance.evidence,
      'page': instance.page,
      'warnings': instance.warnings.map((e) => e.toJson()).toList(),
      'duplicateOf': instance.duplicateOf,
      'selected': instance.selected,
    };
