// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_status_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiStatusResponse _$AiStatusResponseFromJson(Map<String, dynamic> json) =>
    AiStatusResponse(
      configured: json['configured'] as bool,
      models: (json['models'] as List<dynamic>)
          .map((e) => AiModelInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      freeTier: json['freeTier'] as bool,
      thisMonth: AiUsageSummary.fromJson(
        json['thisMonth'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$AiStatusResponseToJson(AiStatusResponse instance) =>
    <String, dynamic>{
      'configured': instance.configured,
      'models': instance.models.map((e) => e.toJson()).toList(),
      'freeTier': instance.freeTier,
      'thisMonth': instance.thisMonth.toJson(),
    };
