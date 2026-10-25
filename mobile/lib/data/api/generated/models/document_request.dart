// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'document_type.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'document_request.g.dart';

@JsonSerializable()
class DocumentRequest {
  const DocumentRequest({
    required this.type,
    required this.title,
    required this.documentDate,
    required this.notes,
    required this.fileIds,
  });
  
  factory DocumentRequest.fromJson(Map<String, Object?> json) => _$DocumentRequestFromJson(json);
  
  final DocumentType type;
  final String? title;
	@DateOnlyConverter()
  final DateTime? documentDate;
  final String? notes;
  final List<String> fileIds;

  Map<String, Object?> toJson() => _$DocumentRequestToJson(this);
}
