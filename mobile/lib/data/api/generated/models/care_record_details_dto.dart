// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'care_record_details_dto.g.dart';

@JsonSerializable()
class CareRecordDetailsDto {
  const CareRecordDetailsDto({
    required this.laboratory,
    required this.reportNumber,
    required this.titerIuPerMl,
    required this.fitForTravel,
  });
  
  factory CareRecordDetailsDto.fromJson(Map<String, Object?> json) => _$CareRecordDetailsDtoFromJson(json);
  
  final String? laboratory;
  final String? reportNumber;
  final double? titerIuPerMl;
  final bool? fitForTravel;

  Map<String, Object?> toJson() => _$CareRecordDetailsDtoToJson(this);
}
