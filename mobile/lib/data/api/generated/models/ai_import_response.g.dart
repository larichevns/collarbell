// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_import_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiImportResponse _$AiImportResponseFromJson(
  Map<String, dynamic> json,
) => AiImportResponse(
  id: json['id'] as String,
  petId: json['petId'] as String,
  source: AiImportSource.fromJson(json['source']),
  status: AiImportStatus.fromJson(json['status']),
  pages: (json['pages'] as List<dynamic>)
      .map((e) => FileLink.fromJson(e as Map<String, dynamic>))
      .toList(),
  draft: json['draft'] == null
      ? null
      : ImportDraft.fromJson(json['draft'] as Map<String, dynamic>),
  error: json['error'] == null ? null : AiImportError.fromJson(json['error']),
  model: json['model'] as String?,
  createdAt: const RequiredDateOnlyConverter().fromJson(
    json['createdAt'] as String,
  ),
  completedAt: const DateOnlyConverter().fromJson(
    json['completedAt'] as String?,
  ),
  appliedAt: const DateOnlyConverter().fromJson(json['appliedAt'] as String?),
  result: json['result'] == null
      ? null
      : ApplyImportResponse.fromJson(json['result'] as Map<String, dynamic>),
  text: json['text'] as String?,
);

Map<String, dynamic> _$AiImportResponseToJson(AiImportResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'petId': instance.petId,
      'source': _$AiImportSourceEnumMap[instance.source]!,
      'status': _$AiImportStatusEnumMap[instance.status]!,
      'pages': instance.pages.map((e) => e.toJson()).toList(),
      'draft': instance.draft?.toJson(),
      'error': _$AiImportErrorEnumMap[instance.error],
      'model': instance.model,
      'createdAt': const RequiredDateOnlyConverter().toJson(instance.createdAt),
      'completedAt': const DateOnlyConverter().toJson(instance.completedAt),
      'appliedAt': const DateOnlyConverter().toJson(instance.appliedAt),
      'result': instance.result?.toJson(),
      'text': instance.text,
    };

const _$AiImportSourceEnumMap = {
  AiImportSource.passportPages: 'PassportPages',
  AiImportSource.vetDocument: 'VetDocument',
  AiImportSource.text: 'Text',
  AiImportSource.$unknown: r'$unknown',
};

const _$AiImportStatusEnumMap = {
  AiImportStatus.queued: 'Queued',
  AiImportStatus.processing: 'Processing',
  AiImportStatus.ready: 'Ready',
  AiImportStatus.applied: 'Applied',
  AiImportStatus.failed: 'Failed',
  AiImportStatus.discarded: 'Discarded',
  AiImportStatus.$unknown: r'$unknown',
};

const _$AiImportErrorEnumMap = {
  AiImportError.notConfigured: 'NotConfigured',
  AiImportError.busy: 'Busy',
  AiImportError.rejected: 'Rejected',
  AiImportError.photosMissing: 'PhotosMissing',
  AiImportError.unexpected: 'Unexpected',
  AiImportError.valueNull: null,
  AiImportError.$unknown: r'$unknown',
};
