// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'existing_supply.dart';
import 'product_details.dart';
import 'product_lookup_source.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'product_lookup_response.g.dart';

@JsonSerializable()
class ProductLookupResponse {
  const ProductLookupResponse({
    required this.code,
    required this.batch,
    required this.expiresOn,
    required this.existing,
    required this.product,
    required this.source,
  });
  
  factory ProductLookupResponse.fromJson(Map<String, Object?> json) => _$ProductLookupResponseFromJson(json);
  
  final String code;
  final String? batch;
	@DateOnlyConverter()
  final DateTime? expiresOn;
  final ExistingSupply? existing;
  final ProductDetails? product;
  final ProductLookupSource? source;

  Map<String, Object?> toJson() => _$ProductLookupResponseToJson(this);
}
