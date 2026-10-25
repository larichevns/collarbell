// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'document_type.dart';
import 'file_link.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'document_response.g.dart';

@JsonSerializable()
class DocumentResponse {
  const DocumentResponse({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    required this.documentDate,
    required this.notes,
    required this.pages,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory DocumentResponse.fromJson(Map<String, Object?> json) => _$DocumentResponseFromJson(json);
  
  final String id;
  final String? petId;
  final DocumentType type;
  final String? title;
	@DateOnlyConverter()
  final DateTime? documentDate;
  final String? notes;
  final List<FileLink> pages;
	@RequiredDateOnlyConverter()
  final DateTime createdAt;
	@RequiredDateOnlyConverter()
  final DateTime updatedAt;

  Map<String, Object?> toJson() => _$DocumentResponseToJson(this);
}
