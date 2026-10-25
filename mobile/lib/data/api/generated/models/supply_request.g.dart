// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supply_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SupplyRequest _$SupplyRequestFromJson(Map<String, dynamic> json) =>
    SupplyRequest(
      name: json['name'] as String,
      brand: json['brand'] as String?,
      barcode: json['barcode'] as String?,
      category: SupplyCategory.fromJson(json['category']),
      unit: SupplyUnit.fromJson(json['unit']),
      packageSize: (json['packageSize'] as num).toDouble(),
      kcalPerKg: (json['kcalPerKg'] as num?)?.toInt(),
      usageMode: json['usageMode'] == null
          ? null
          : SupplyUsageMode.fromJson(json['usageMode']),
      manualDailyUsage: (json['manualDailyUsage'] as num?)?.toDouble(),
      leadTimeDays: (json['leadTimeDays'] as num?)?.toInt(),
      storeUrl: json['storeUrl'] as String?,
      notes: json['notes'] as String?,
      active: json['active'] as bool?,
      initialStock: (json['initialStock'] as num?)?.toDouble(),
      dataSource: json['dataSource'] == null
          ? null
          : SupplyDataSource.fromJson(json['dataSource']),
      requestId: json['requestId'] as String?,
    );

Map<String, dynamic> _$SupplyRequestToJson(SupplyRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'brand': instance.brand,
      'barcode': instance.barcode,
      'category': _$SupplyCategoryEnumMap[instance.category]!,
      'unit': _$SupplyUnitEnumMap[instance.unit]!,
      'packageSize': instance.packageSize,
      'kcalPerKg': instance.kcalPerKg,
      'usageMode': _$SupplyUsageModeEnumMap[instance.usageMode],
      'manualDailyUsage': instance.manualDailyUsage,
      'leadTimeDays': instance.leadTimeDays,
      'storeUrl': instance.storeUrl,
      'notes': instance.notes,
      'active': instance.active,
      'initialStock': instance.initialStock,
      'dataSource': _$SupplyDataSourceEnumMap[instance.dataSource],
      'requestId': instance.requestId,
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

const _$SupplyDataSourceEnumMap = {
  SupplyDataSource.manual: 'Manual',
  SupplyDataSource.catalog: 'Catalog',
  SupplyDataSource.openPetFoodFacts: 'OpenPetFoodFacts',
  SupplyDataSource.upcItemDb: 'UpcItemDb',
  SupplyDataSource.ai: 'Ai',
  SupplyDataSource.valueNull: null,
  SupplyDataSource.$unknown: r'$unknown',
};
