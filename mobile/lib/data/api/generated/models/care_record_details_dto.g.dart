// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'care_record_details_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CareRecordDetailsDto _$CareRecordDetailsDtoFromJson(
  Map<String, dynamic> json,
) => CareRecordDetailsDto(
  laboratory: json['laboratory'] as String?,
  reportNumber: json['reportNumber'] as String?,
  titerIuPerMl: (json['titerIuPerMl'] as num?)?.toDouble(),
  fitForTravel: json['fitForTravel'] as bool?,
);

Map<String, dynamic> _$CareRecordDetailsDtoToJson(
  CareRecordDetailsDto instance,
) => <String, dynamic>{
  'laboratory': instance.laboratory,
  'reportNumber': instance.reportNumber,
  'titerIuPerMl': instance.titerIuPerMl,
  'fitForTravel': instance.fitForTravel,
};
