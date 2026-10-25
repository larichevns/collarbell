// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passport_records_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PassportRecordsResponse _$PassportRecordsResponseFromJson(
  Map<String, dynamic> json,
) => PassportRecordsResponse(
  rabies: (json['rabies'] as List<dynamic>)
      .map((e) => CareRecordResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  rabiesTiters: (json['rabiesTiters'] as List<dynamic>)
      .map((e) => CareRecordResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  echinococcus: (json['echinococcus'] as List<dynamic>)
      .map((e) => CareRecordResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  treatments: (json['treatments'] as List<dynamic>)
      .map((e) => CareRecordResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  otherVaccinations: (json['otherVaccinations'] as List<dynamic>)
      .map((e) => CareRecordResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  examinations: (json['examinations'] as List<dynamic>)
      .map((e) => CareRecordResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PassportRecordsResponseToJson(
  PassportRecordsResponse instance,
) => <String, dynamic>{
  'rabies': instance.rabies.map((e) => e.toJson()).toList(),
  'rabiesTiters': instance.rabiesTiters.map((e) => e.toJson()).toList(),
  'echinococcus': instance.echinococcus.map((e) => e.toJson()).toList(),
  'treatments': instance.treatments.map((e) => e.toJson()).toList(),
  'otherVaccinations': instance.otherVaccinations
      .map((e) => e.toJson())
      .toList(),
  'examinations': instance.examinations.map((e) => e.toJson()).toList(),
};
