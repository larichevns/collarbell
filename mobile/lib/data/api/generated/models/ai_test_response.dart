// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'ai_test_problem.dart';

part 'ai_test_response.g.dart';

@JsonSerializable()
class AiTestResponse {
  const AiTestResponse({
    required this.ok,
    required this.model,
    required this.latencyMs,
    required this.problem,
  });
  
  factory AiTestResponse.fromJson(Map<String, Object?> json) => _$AiTestResponseFromJson(json);
  
  final bool ok;
  final String? model;
  final int latencyMs;
  final AiTestProblem? problem;

  Map<String, Object?> toJson() => _$AiTestResponseToJson(this);
}
