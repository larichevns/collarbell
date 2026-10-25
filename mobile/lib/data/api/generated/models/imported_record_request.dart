// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_record_request.dart';

part 'imported_record_request.g.dart';

@JsonSerializable()
class ImportedRecordRequest {
  const ImportedRecordRequest({
    required this.record,
    required this.planId,
  });
  
  factory ImportedRecordRequest.fromJson(Map<String, Object?> json) => _$ImportedRecordRequestFromJson(json);
  
  final CareRecordRequest record;
  final String? planId;

  Map<String, Object?> toJson() => _$ImportedRecordRequestToJson(this);
}
