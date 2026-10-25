// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoutineRequest _$RoutineRequestFromJson(Map<String, dynamic> json) =>
    RoutineRequest(
      kind: json['kind'] == null ? null : RoutineKind.fromJson(json['kind']),
      times: (json['times'] as List<dynamic>).map((e) => e as String).toList(),
      days: (json['days'] as List<dynamic>?)?.map(DayOfWeek.fromJson).toList(),
      food: json['food'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      unit: json['unit'] == null ? null : PortionUnit.fromJson(json['unit']),
      notes: json['notes'] as String?,
      active: json['active'] as bool?,
      requestId: json['requestId'] as String?,
      supplyItemId: json['supplyItemId'] as String?,
    );

Map<String, dynamic> _$RoutineRequestToJson(RoutineRequest instance) =>
    <String, dynamic>{
      'kind': _$RoutineKindEnumMap[instance.kind],
      'times': instance.times,
      'days': instance.days?.map((e) => _$DayOfWeekEnumMap[e]!).toList(),
      'food': instance.food,
      'amount': instance.amount,
      'unit': _$PortionUnitEnumMap[instance.unit],
      'notes': instance.notes,
      'active': instance.active,
      'requestId': instance.requestId,
      'supplyItemId': instance.supplyItemId,
    };

const _$RoutineKindEnumMap = {
  RoutineKind.feeding: 'Feeding',
  RoutineKind.$unknown: r'$unknown',
};

const _$DayOfWeekEnumMap = {
  DayOfWeek.sunday: 'Sunday',
  DayOfWeek.monday: 'Monday',
  DayOfWeek.tuesday: 'Tuesday',
  DayOfWeek.wednesday: 'Wednesday',
  DayOfWeek.thursday: 'Thursday',
  DayOfWeek.friday: 'Friday',
  DayOfWeek.saturday: 'Saturday',
  DayOfWeek.$unknown: r'$unknown',
};

const _$PortionUnitEnumMap = {
  PortionUnit.gram: 'Gram',
  PortionUnit.milliliter: 'Milliliter',
  PortionUnit.piece: 'Piece',
  PortionUnit.valueNull: null,
  PortionUnit.$unknown: r'$unknown',
};
