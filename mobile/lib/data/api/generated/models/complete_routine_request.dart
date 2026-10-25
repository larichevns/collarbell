// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'completion_status.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'complete_routine_request.g.dart';

@JsonSerializable()
class CompleteRoutineRequest {
  const CompleteRoutineRequest({
    required this.date,
    required this.time,
    required this.status,
  });
  
  factory CompleteRoutineRequest.fromJson(Map<String, Object?> json) => _$CompleteRoutineRequestFromJson(json);
  
	@RequiredDateOnlyConverter()
  final DateTime date;
  final String time;
  final CompletionStatus? status;

  Map<String, Object?> toJson() => _$CompleteRoutineRequestToJson(this);
}
