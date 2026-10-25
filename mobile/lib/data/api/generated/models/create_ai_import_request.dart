// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'ai_import_source.dart';

part 'create_ai_import_request.g.dart';

@JsonSerializable()
class CreateAiImportRequest {
  const CreateAiImportRequest({
    required this.petId,
    required this.source,
    required this.fileIds,
    required this.requestId,
    this.text,
    this.retryOf,
  });
  
  factory CreateAiImportRequest.fromJson(Map<String, Object?> json) => _$CreateAiImportRequestFromJson(json);
  
  final String petId;
  final AiImportSource source;
  final List<String> fileIds;
  final String? requestId;
  final String? text;
  final String? retryOf;

  Map<String, Object?> toJson() => _$CreateAiImportRequestToJson(this);
}
