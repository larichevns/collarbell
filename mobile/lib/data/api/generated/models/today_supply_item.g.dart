// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_supply_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TodaySupplyItem _$TodaySupplyItemFromJson(Map<String, dynamic> json) =>
    TodaySupplyItem(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      category: SupplyCategory.fromJson(json['category']),
      unit: SupplyUnit.fromJson(json['unit']),
      packageSize: (json['packageSize'] as num).toDouble(),
      status: SupplyStatus.fromJson(json['status']),
      remaining: (json['remaining'] as num?)?.toDouble(),
      daysLeft: (json['daysLeft'] as num?)?.toDouble(),
      runsOutOn: const DateOnlyConverter().fromJson(
        json['runsOutOn'] as String?,
      ),
    );

Map<String, dynamic> _$TodaySupplyItemToJson(TodaySupplyItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'brand': instance.brand,
      'category': _$SupplyCategoryEnumMap[instance.category]!,
      'unit': _$SupplyUnitEnumMap[instance.unit]!,
      'packageSize': instance.packageSize,
      'status': _$SupplyStatusEnumMap[instance.status]!,
      'remaining': instance.remaining,
      'daysLeft': instance.daysLeft,
      'runsOutOn': const DateOnlyConverter().toJson(instance.runsOutOn),
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

const _$SupplyStatusEnumMap = {
  SupplyStatus.noStock: 'NoStock',
  SupplyStatus.noUsage: 'NoUsage',
  SupplyStatus.enough: 'Enough',
  SupplyStatus.soon: 'Soon',
  SupplyStatus.buyNow: 'BuyNow',
  SupplyStatus.outOfStock: 'OutOfStock',
  SupplyStatus.$unknown: r'$unknown',
};
