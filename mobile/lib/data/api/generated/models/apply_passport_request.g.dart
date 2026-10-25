// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apply_passport_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplyPassportRequest _$ApplyPassportRequestFromJson(
  Map<String, dynamic> json,
) => ApplyPassportRequest(
  passportNumber: json['passportNumber'] as String?,
  issuingCountry: json['issuingCountry'] as String?,
  issuedOn: const DateOnlyConverter().fromJson(json['issuedOn'] as String?),
);

Map<String, dynamic> _$ApplyPassportRequestToJson(
  ApplyPassportRequest instance,
) => <String, dynamic>{
  'passportNumber': instance.passportNumber,
  'issuingCountry': instance.issuingCountry,
  'issuedOn': const DateOnlyConverter().toJson(instance.issuedOn),
};
