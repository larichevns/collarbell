// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'product_scan_request.g.dart';

@JsonSerializable()
class ProductScanRequest {
  const ProductScanRequest({
    required this.fileIds,
    required this.barcode,
  });
  
  factory ProductScanRequest.fromJson(Map<String, Object?> json) => _$ProductScanRequestFromJson(json);
  
  final List<String> fileIds;
  final String? barcode;

  Map<String, Object?> toJson() => _$ProductScanRequestToJson(this);
}
