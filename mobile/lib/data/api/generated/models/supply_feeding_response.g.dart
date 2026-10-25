// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supply_feeding_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SupplyFeedingResponse _$SupplyFeedingResponseFromJson(
  Map<String, dynamic> json,
) => SupplyFeedingResponse(
  routineId: json['routineId'] as String,
  petId: json['petId'] as String,
  petName: json['petName'] as String,
  amount: (json['amount'] as num?)?.toDouble(),
  unit: json['unit'] == null ? null : PortionUnit.fromJson(json['unit']),
  timesPerDay: (json['timesPerDay'] as num).toDouble(),
  counted: json['counted'] as bool,
);

Map<String, dynamic> _$SupplyFeedingResponseToJson(
  SupplyFeedingResponse instance,
) => <String, dynamic>{
  'routineId': instance.routineId,
  'petId': instance.petId,
  'petName': instance.petName,
  'amount': instance.amount,
  'unit': _$PortionUnitEnumMap[instance.unit],
  'timesPerDay': instance.timesPerDay,
  'counted': instance.counted,
};

const _$PortionUnitEnumMap = {
  PortionUnit.gram: 'Gram',
  PortionUnit.milliliter: 'Milliliter',
  PortionUnit.piece: 'Piece',
  PortionUnit.valueNull: null,
  PortionUnit.$unknown: r'$unknown',
};
