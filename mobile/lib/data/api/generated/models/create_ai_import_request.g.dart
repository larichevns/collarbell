// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_ai_import_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAiImportRequest _$CreateAiImportRequestFromJson(
  Map<String, dynamic> json,
) => CreateAiImportRequest(
  petId: json['petId'] as String,
  source: AiImportSource.fromJson(json['source']),
  fileIds: (json['fileIds'] as List<dynamic>).map((e) => e as String).toList(),
  requestId: json['requestId'] as String?,
  text: json['text'] as String?,
  retryOf: json['retryOf'] as String?,
);

Map<String, dynamic> _$CreateAiImportRequestToJson(
  CreateAiImportRequest instance,
) => <String, dynamic>{
  'petId': instance.petId,
  'source': _$AiImportSourceEnumMap[instance.source]!,
  'fileIds': instance.fileIds,
  'requestId': instance.requestId,
  'text': instance.text,
  'retryOf': instance.retryOf,
};

const _$AiImportSourceEnumMap = {
  AiImportSource.passportPages: 'PassportPages',
  AiImportSource.vetDocument: 'VetDocument',
  AiImportSource.text: 'Text',
  AiImportSource.$unknown: r'$unknown',
};
