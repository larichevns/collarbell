// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_draft.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImportDraft _$ImportDraftFromJson(Map<String, dynamic> json) => ImportDraft(
  records: (json['records'] as List<dynamic>)
      .map((e) => DraftRecord.fromJson(e as Map<String, dynamic>))
      .toList(),
  identifiers: (json['identifiers'] as List<dynamic>)
      .map((e) => DraftIdentifier.fromJson(e as Map<String, dynamic>))
      .toList(),
  passport: json['passport'] == null
      ? null
      : DraftPassport.fromJson(json['passport'] as Map<String, dynamic>),
  weights: (json['weights'] as List<dynamic>)
      .map((e) => DraftWeight.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ImportDraftToJson(ImportDraft instance) =>
    <String, dynamic>{
      'records': instance.records.map((e) => e.toJson()).toList(),
      'identifiers': instance.identifiers.map((e) => e.toJson()).toList(),
      'passport': instance.passport?.toJson(),
      'weights': instance.weights.map((e) => e.toJson()).toList(),
    };
