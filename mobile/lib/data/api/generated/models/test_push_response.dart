// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'test_push_problem.dart';

part 'test_push_response.g.dart';

@JsonSerializable()
class TestPushResponse {
  const TestPushResponse({
    required this.devices,
    required this.delivered,
    required this.problem,
  });
  
  factory TestPushResponse.fromJson(Map<String, Object?> json) => _$TestPushResponseFromJson(json);
  
  final int devices;
  final int delivered;
  final TestPushProblem? problem;

  Map<String, Object?> toJson() => _$TestPushResponseToJson(this);
}
