// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'ai_usage_summary.g.dart';

@JsonSerializable()
class AiUsageSummary {
  const AiUsageSummary({
    required this.requests,
    required this.inputTokens,
    required this.outputTokens,
  });
  
  factory AiUsageSummary.fromJson(Map<String, Object?> json) => _$AiUsageSummaryFromJson(json);
  
  final int requests;
  final int inputTokens;
  final int outputTokens;

  Map<String, Object?> toJson() => _$AiUsageSummaryToJson(this);
}
