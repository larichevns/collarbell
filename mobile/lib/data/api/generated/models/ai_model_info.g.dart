// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_model_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiModelInfo _$AiModelInfoFromJson(Map<String, dynamic> json) => AiModelInfo(
  provider: AiProvider.fromJson(json['provider']),
  model: json['model'] as String,
  ready: json['ready'] as bool,
);

Map<String, dynamic> _$AiModelInfoToJson(AiModelInfo instance) =>
    <String, dynamic>{
      'provider': _$AiProviderEnumMap[instance.provider]!,
      'model': instance.model,
      'ready': instance.ready,
    };

const _$AiProviderEnumMap = {
  AiProvider.gemini: 'Gemini',
  AiProvider.openAiCompatible: 'OpenAICompatible',
  AiProvider.ollama: 'Ollama',
  AiProvider.$unknown: r'$unknown',
};
