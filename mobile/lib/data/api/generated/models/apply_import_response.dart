// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'apply_import_response.g.dart';

@JsonSerializable()
class ApplyImportResponse {
  const ApplyImportResponse({
    required this.recordIds,
    required this.plansMoved,
    required this.identifiersAdded,
    required this.passportUpdated,
    required this.documentId,
    this.weightsAdded = 0,
  });
  
  factory ApplyImportResponse.fromJson(Map<String, Object?> json) => _$ApplyImportResponseFromJson(json);
  
  final List<String> recordIds;
  final int plansMoved;
  final int identifiersAdded;
  final bool passportUpdated;
  final String? documentId;
  final int weightsAdded;

  Map<String, Object?> toJson() => _$ApplyImportResponseToJson(this);
}
