// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'supply_category.dart';
import 'supply_unit.dart';

part 'product_details.g.dart';

@JsonSerializable()
class ProductDetails {
  const ProductDetails({
    required this.name,
    required this.brand,
    required this.category,
    required this.unit,
    required this.packageSize,
    required this.kcalPerKg,
  });
  
  factory ProductDetails.fromJson(Map<String, Object?> json) => _$ProductDetailsFromJson(json);
  
  final String name;
  final String? brand;
  final SupplyCategory? category;
  final SupplyUnit? unit;
  final double? packageSize;
  final int? kcalPerKg;

  Map<String, Object?> toJson() => _$ProductDetailsToJson(this);
}
