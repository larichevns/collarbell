// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supply_forecast.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SupplyForecast _$SupplyForecastFromJson(Map<String, dynamic> json) =>
    SupplyForecast(
      remaining: (json['remaining'] as num?)?.toDouble(),
      usagePerDay: (json['usagePerDay'] as num?)?.toDouble(),
      daysLeft: (json['daysLeft'] as num?)?.toDouble(),
      runsOutOn: const DateOnlyConverter().fromJson(
        json['runsOutOn'] as String?,
      ),
      buyBy: const DateOnlyConverter().fromJson(json['buyBy'] as String?),
      status: SupplyStatus.fromJson(json['status']),
      countedFrom: const DateOnlyConverter().fromJson(
        json['countedFrom'] as String?,
      ),
    );

Map<String, dynamic> _$SupplyForecastToJson(SupplyForecast instance) =>
    <String, dynamic>{
      'remaining': instance.remaining,
      'usagePerDay': instance.usagePerDay,
      'daysLeft': instance.daysLeft,
      'runsOutOn': const DateOnlyConverter().toJson(instance.runsOutOn),
      'buyBy': const DateOnlyConverter().toJson(instance.buyBy),
      'status': _$SupplyStatusEnumMap[instance.status]!,
      'countedFrom': const DateOnlyConverter().toJson(instance.countedFrom),
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
