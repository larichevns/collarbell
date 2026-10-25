// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passport_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PassportRequest _$PassportRequestFromJson(Map<String, dynamic> json) =>
    PassportRequest(
      model: json['model'] == null
          ? null
          : PassportModel.fromJson(json['model']),
      passportNumber: json['passportNumber'] as String?,
      issuingCountry: json['issuingCountry'] as String?,
      issuedOn: const DateOnlyConverter().fromJson(json['issuedOn'] as String?),
      issuer: json['issuer'] == null
          ? null
          : PassportContactDto.fromJson(json['issuer'] as Map<String, dynamic>),
      owners: (json['owners'] as List<dynamic>?)
          ?.map((e) => PassportContactDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$PassportRequestToJson(PassportRequest instance) =>
    <String, dynamic>{
      'model': _$PassportModelEnumMap[instance.model],
      'passportNumber': instance.passportNumber,
      'issuingCountry': instance.issuingCountry,
      'issuedOn': const DateOnlyConverter().toJson(instance.issuedOn),
      'issuer': instance.issuer?.toJson(),
      'owners': instance.owners?.map((e) => e.toJson()).toList(),
      'notes': instance.notes,
    };

const _$PassportModelEnumMap = {
  PassportModel.eu2014: 'Eu2014',
  PassportModel.eu2026: 'Eu2026',
  PassportModel.other: 'Other',
  PassportModel.valueNull: null,
  PassportModel.$unknown: r'$unknown',
};
