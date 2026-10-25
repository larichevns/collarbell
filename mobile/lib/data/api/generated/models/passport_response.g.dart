// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passport_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PassportResponse _$PassportResponseFromJson(
  Map<String, dynamic> json,
) => PassportResponse(
  petId: json['petId'] as String,
  model: json['model'] == null ? null : PassportModel.fromJson(json['model']),
  passportNumber: json['passportNumber'] as String?,
  issuingCountry: json['issuingCountry'] as String?,
  issuedOn: const DateOnlyConverter().fromJson(json['issuedOn'] as String?),
  issuer: json['issuer'] == null
      ? null
      : PassportContactDto.fromJson(json['issuer'] as Map<String, dynamic>),
  owners: (json['owners'] as List<dynamic>)
      .map((e) => PassportContactDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  notes: json['notes'] as String?,
  updatedAt: const DateOnlyConverter().fromJson(json['updatedAt'] as String?),
);

Map<String, dynamic> _$PassportResponseToJson(PassportResponse instance) =>
    <String, dynamic>{
      'petId': instance.petId,
      'model': _$PassportModelEnumMap[instance.model],
      'passportNumber': instance.passportNumber,
      'issuingCountry': instance.issuingCountry,
      'issuedOn': const DateOnlyConverter().toJson(instance.issuedOn),
      'issuer': instance.issuer?.toJson(),
      'owners': instance.owners.map((e) => e.toJson()).toList(),
      'notes': instance.notes,
      'updatedAt': const DateOnlyConverter().toJson(instance.updatedAt),
    };

const _$PassportModelEnumMap = {
  PassportModel.eu2014: 'Eu2014',
  PassportModel.eu2026: 'Eu2026',
  PassportModel.other: 'Other',
  PassportModel.valueNull: null,
  PassportModel.$unknown: r'$unknown',
};
