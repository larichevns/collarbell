// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_passport.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DraftPassport _$DraftPassportFromJson(Map<String, dynamic> json) =>
    DraftPassport(
      passportNumber: json['passportNumber'] as String?,
      issuingCountry: json['issuingCountry'] as String?,
      issuedOn: const DateOnlyConverter().fromJson(json['issuedOn'] as String?),
      evidence: json['evidence'] as String?,
      page: (json['page'] as num).toInt(),
      warnings: (json['warnings'] as List<dynamic>)
          .map((e) => DraftWarning.fromJson(e as Map<String, dynamic>))
          .toList(),
      selected: json['selected'] as bool,
    );

Map<String, dynamic> _$DraftPassportToJson(DraftPassport instance) =>
    <String, dynamic>{
      'passportNumber': instance.passportNumber,
      'issuingCountry': instance.issuingCountry,
      'issuedOn': const DateOnlyConverter().toJson(instance.issuedOn),
      'evidence': instance.evidence,
      'page': instance.page,
      'warnings': instance.warnings.map((e) => e.toJson()).toList(),
      'selected': instance.selected,
    };
