// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'ai_provider.dart';

part 'ai_model_info.g.dart';

@JsonSerializable()
class AiModelInfo {
  const AiModelInfo({
    required this.provider,
    required this.model,
    required this.ready,
  });
  
  factory AiModelInfo.fromJson(Map<String, Object?> json) => _$AiModelInfoFromJson(json);
  
  final AiProvider provider;
  final String model;
  final bool ready;

  Map<String, Object?> toJson() => _$AiModelInfoToJson(this);
}
