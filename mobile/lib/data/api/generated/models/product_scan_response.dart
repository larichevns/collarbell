// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'product_draft.dart';

part 'product_scan_response.g.dart';

@JsonSerializable()
class ProductScanResponse {
  const ProductScanResponse({
    required this.product,
    required this.model,
  });
  
  factory ProductScanResponse.fromJson(Map<String, Object?> json) => _$ProductScanResponseFromJson(json);
  
  final ProductDraft product;
  final String model;

  Map<String, Object?> toJson() => _$ProductScanResponseToJson(this);
}
