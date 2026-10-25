// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'completion_status.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'routine_completion_response.g.dart';

@JsonSerializable()
class RoutineCompletionResponse {
  const RoutineCompletionResponse({
    required this.id,
    required this.routineId,
    required this.date,
    required this.time,
    required this.status,
    required this.doneAt,
    required this.byName,
    required this.byMe,
  });
  
  factory RoutineCompletionResponse.fromJson(Map<String, Object?> json) => _$RoutineCompletionResponseFromJson(json);
  
  final String id;
  final String routineId;
	@RequiredDateOnlyConverter()
  final DateTime date;
  final String time;
  final CompletionStatus status;
	@RequiredDateOnlyConverter()
  final DateTime doneAt;
  final String? byName;
  final bool byMe;

  Map<String, Object?> toJson() => _$RoutineCompletionResponseToJson(this);
}
