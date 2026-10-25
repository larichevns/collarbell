// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'identifier_scan_request.g.dart';

@JsonSerializable()
class IdentifierScanRequest {
  const IdentifierScanRequest({
    required this.fileIds,
  });
  
  factory IdentifierScanRequest.fromJson(Map<String, Object?> json) => _$IdentifierScanRequestFromJson(json);
  
  final List<String> fileIds;

  Map<String, Object?> toJson() => _$IdentifierScanRequestToJson(this);
}
