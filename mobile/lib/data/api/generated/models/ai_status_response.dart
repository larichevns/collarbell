// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'ai_model_info.dart';
import 'ai_usage_summary.dart';

part 'ai_status_response.g.dart';

@JsonSerializable()
class AiStatusResponse {
  const AiStatusResponse({
    required this.configured,
    required this.models,
    required this.freeTier,
    required this.thisMonth,
  });
  
  factory AiStatusResponse.fromJson(Map<String, Object?> json) => _$AiStatusResponseFromJson(json);
  
  final bool configured;
  final List<AiModelInfo> models;
  final bool freeTier;
  final AiUsageSummary thisMonth;

  Map<String, Object?> toJson() => _$AiStatusResponseToJson(this);
}
