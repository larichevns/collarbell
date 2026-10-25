// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_feeding_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TodayFeedingItem _$TodayFeedingItemFromJson(Map<String, dynamic> json) =>
    TodayFeedingItem(
      routineId: json['routineId'] as String,
      petId: json['petId'] as String,
      petName: json['petName'] as String,
      petCoat: Coat.fromJson(json['petCoat']),
      petPhoto: json['petPhoto'] == null
          ? null
          : FileLink.fromJson(json['petPhoto'] as Map<String, dynamic>),
      time: json['time'] as String,
      food: json['food'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      unit: json['unit'] == null ? null : PortionUnit.fromJson(json['unit']),
      mark: json['mark'] == null
          ? null
          : RoutineCompletionResponse.fromJson(
              json['mark'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$TodayFeedingItemToJson(TodayFeedingItem instance) =>
    <String, dynamic>{
      'routineId': instance.routineId,
      'petId': instance.petId,
      'petName': instance.petName,
      'petCoat': _$CoatEnumMap[instance.petCoat]!,
      'petPhoto': instance.petPhoto?.toJson(),
      'time': instance.time,
      'food': instance.food,
      'amount': instance.amount,
      'unit': _$PortionUnitEnumMap[instance.unit],
      'mark': instance.mark?.toJson(),
    };

const _$CoatEnumMap = {
  Coat.smoke: 'Smoke',
  Coat.ginger: 'Ginger',
  Coat.fawn: 'Fawn',
  Coat.cocoa: 'Cocoa',
  Coat.lilac: 'Lilac',
  Coat.ink: 'Ink',
  Coat.$unknown: r'$unknown',
};

const _$PortionUnitEnumMap = {
  PortionUnit.gram: 'Gram',
  PortionUnit.milliliter: 'Milliliter',
  PortionUnit.piece: 'Piece',
  PortionUnit.valueNull: null,
  PortionUnit.$unknown: r'$unknown',
};
