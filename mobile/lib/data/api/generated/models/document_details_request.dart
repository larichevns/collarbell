// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'document_type.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'document_details_request.g.dart';

@JsonSerializable()
class DocumentDetailsRequest {
  const DocumentDetailsRequest({
    required this.type,
    required this.title,
    required this.documentDate,
    required this.notes,
  });
  
  factory DocumentDetailsRequest.fromJson(Map<String, Object?> json) => _$DocumentDetailsRequestFromJson(json);
  
  final DocumentType type;
  final String? title;
	@DateOnlyConverter()
  final DateTime? documentDate;
  final String? notes;

  Map<String, Object?> toJson() => _$DocumentDetailsRequestToJson(this);
}
