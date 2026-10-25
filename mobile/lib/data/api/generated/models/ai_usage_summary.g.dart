// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_usage_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiUsageSummary _$AiUsageSummaryFromJson(Map<String, dynamic> json) =>
    AiUsageSummary(
      requests: (json['requests'] as num).toInt(),
      inputTokens: (json['inputTokens'] as num).toInt(),
      outputTokens: (json['outputTokens'] as num).toInt(),
    );

Map<String, dynamic> _$AiUsageSummaryToJson(AiUsageSummary instance) =>
    <String, dynamic>{
      'requests': instance.requests,
      'inputTokens': instance.inputTokens,
      'outputTokens': instance.outputTokens,
    };
