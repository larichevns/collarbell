// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_record_response.dart';

part 'passport_records_response.g.dart';

@JsonSerializable()
class PassportRecordsResponse {
  const PassportRecordsResponse({
    required this.rabies,
    required this.rabiesTiters,
    required this.echinococcus,
    required this.treatments,
    required this.otherVaccinations,
    required this.examinations,
  });
  
  factory PassportRecordsResponse.fromJson(Map<String, Object?> json) => _$PassportRecordsResponseFromJson(json);
  
  final List<CareRecordResponse> rabies;
  final List<CareRecordResponse> rabiesTiters;
  final List<CareRecordResponse> echinococcus;
  final List<CareRecordResponse> treatments;
  final List<CareRecordResponse> otherVaccinations;
  final List<CareRecordResponse> examinations;

  Map<String, Object?> toJson() => _$PassportRecordsResponseToJson(this);
}
