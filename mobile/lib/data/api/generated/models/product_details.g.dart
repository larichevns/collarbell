// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductDetails _$ProductDetailsFromJson(Map<String, dynamic> json) =>
    ProductDetails(
      name: json['name'] as String,
      brand: json['brand'] as String?,
      category: json['category'] == null
          ? null
          : SupplyCategory.fromJson(json['category']),
      unit: json['unit'] == null ? null : SupplyUnit.fromJson(json['unit']),
      packageSize: (json['packageSize'] as num?)?.toDouble(),
      kcalPerKg: (json['kcalPerKg'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ProductDetailsToJson(ProductDetails instance) =>
    <String, dynamic>{
      'name': instance.name,
      'brand': instance.brand,
      'category': _$SupplyCategoryEnumMap[instance.category],
      'unit': _$SupplyUnitEnumMap[instance.unit],
      'packageSize': instance.packageSize,
      'kcalPerKg': instance.kcalPerKg,
    };

const _$SupplyCategoryEnumMap = {
  SupplyCategory.dryFood: 'DryFood',
  SupplyCategory.wetFood: 'WetFood',
  SupplyCategory.treats: 'Treats',
  SupplyCategory.litter: 'Litter',
  SupplyCategory.medication: 'Medication',
  SupplyCategory.other: 'Other',
  SupplyCategory.$unknown: r'$unknown',
};

const _$SupplyUnitEnumMap = {
  SupplyUnit.gram: 'Gram',
  SupplyUnit.milliliter: 'Milliliter',
  SupplyUnit.piece: 'Piece',
  SupplyUnit.dose: 'Dose',
  SupplyUnit.$unknown: r'$unknown',
};
