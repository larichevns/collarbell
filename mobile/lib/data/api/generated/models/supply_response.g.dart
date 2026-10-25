// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supply_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SupplyResponse _$SupplyResponseFromJson(Map<String, dynamic> json) =>
    SupplyResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      barcode: json['barcode'] as String?,
      category: SupplyCategory.fromJson(json['category']),
      unit: SupplyUnit.fromJson(json['unit']),
      packageSize: (json['packageSize'] as num).toDouble(),
      kcalPerKg: (json['kcalPerKg'] as num?)?.toInt(),
      usageMode: SupplyUsageMode.fromJson(json['usageMode']),
      manualDailyUsage: (json['manualDailyUsage'] as num?)?.toDouble(),
      leadTimeDays: (json['leadTimeDays'] as num).toInt(),
      storeUrl: json['storeUrl'] as String?,
      notes: json['notes'] as String?,
      active: json['active'] as bool,
      forecast: SupplyForecast.fromJson(
        json['forecast'] as Map<String, dynamic>,
      ),
      feedings: (json['feedings'] as List<dynamic>)
          .map((e) => SupplyFeedingResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: const RequiredDateOnlyConverter().fromJson(
        json['createdAt'] as String,
      ),
      updatedAt: const RequiredDateOnlyConverter().fromJson(
        json['updatedAt'] as String,
      ),
    );

Map<String, dynamic> _$SupplyResponseToJson(SupplyResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'brand': instance.brand,
      'barcode': instance.barcode,
      'category': _$SupplyCategoryEnumMap[instance.category]!,
      'unit': _$SupplyUnitEnumMap[instance.unit]!,
      'packageSize': instance.packageSize,
      'kcalPerKg': instance.kcalPerKg,
      'usageMode': _$SupplyUsageModeEnumMap[instance.usageMode]!,
      'manualDailyUsage': instance.manualDailyUsage,
      'leadTimeDays': instance.leadTimeDays,
      'storeUrl': instance.storeUrl,
      'notes': instance.notes,
      'active': instance.active,
      'forecast': instance.forecast.toJson(),
      'feedings': instance.feedings.map((e) => e.toJson()).toList(),
      'createdAt': const RequiredDateOnlyConverter().toJson(instance.createdAt),
      'updatedAt': const RequiredDateOnlyConverter().toJson(instance.updatedAt),
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

const _$SupplyUsageModeEnumMap = {
  SupplyUsageMode.feeding: 'Feeding',
  SupplyUsageMode.manual: 'Manual',
  SupplyUsageMode.$unknown: r'$unknown',
};
