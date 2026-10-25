// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'ai_import_error.dart';
import 'ai_import_source.dart';
import 'ai_import_status.dart';
import 'apply_import_response.dart';
import 'file_link.dart';
import 'import_draft.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'ai_import_response.g.dart';

@JsonSerializable()
class AiImportResponse {
  const AiImportResponse({
    required this.id,
    required this.petId,
    required this.source,
    required this.status,
    required this.pages,
    required this.draft,
    required this.error,
    required this.model,
    required this.createdAt,
    required this.completedAt,
    required this.appliedAt,
    required this.result,
    required this.text,
  });
  
  factory AiImportResponse.fromJson(Map<String, Object?> json) => _$AiImportResponseFromJson(json);
  
  final String id;
  final String petId;
  final AiImportSource source;
  final AiImportStatus status;
  final List<FileLink> pages;
  final ImportDraft? draft;
  final AiImportError? error;
  final String? model;
	@RequiredDateOnlyConverter()
  final DateTime createdAt;
	@DateOnlyConverter()
  final DateTime? completedAt;
	@DateOnlyConverter()
  final DateTime? appliedAt;
  final ApplyImportResponse? result;
  final String? text;

  Map<String, Object?> toJson() => _$AiImportResponseToJson(this);
}
