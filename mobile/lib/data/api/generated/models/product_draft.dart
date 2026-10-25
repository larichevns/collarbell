// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_kind.dart';
import 'product_species.dart';
import 'supply_category.dart';
import 'supply_unit.dart';

part 'product_draft.g.dart';

@JsonSerializable()
class ProductDraft {
  const ProductDraft({
    required this.isPetProduct,
    required this.name,
    required this.brand,
    required this.category,
    required this.unit,
    required this.packageSize,
    required this.kcalPerKg,
    required this.barcode,
    required this.species,
    required this.treatment,
    required this.protectionWeeks,
    required this.dosesInPackage,
    required this.evidence,
  });
  
  factory ProductDraft.fromJson(Map<String, Object?> json) => _$ProductDraftFromJson(json);
  
  final bool isPetProduct;
  final String? name;
  final String? brand;
  final SupplyCategory? category;
  final SupplyUnit? unit;
  final double? packageSize;
  final int? kcalPerKg;
  final String? barcode;
  final ProductSpecies? species;
  final CareKind? treatment;
  final int? protectionWeeks;
  final int? dosesInPackage;
  final String? evidence;

  Map<String, Object?> toJson() => _$ProductDraftToJson(this);
}
