// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'identifier_reading.dart';

part 'identifier_scan_response.g.dart';

@JsonSerializable()
class IdentifierScanResponse {
  const IdentifierScanResponse({
    required this.identifiers,
    required this.model,
  });
  
  factory IdentifierScanResponse.fromJson(Map<String, Object?> json) => _$IdentifierScanResponseFromJson(json);
  
  final List<IdentifierReading> identifiers;
  final String model;

  Map<String, Object?> toJson() => _$IdentifierScanResponseToJson(this);
}
