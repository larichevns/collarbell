// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'coat.dart';
import 'file_link.dart';
import 'portion_unit.dart';
import 'routine_completion_response.dart';

part 'today_feeding_item.g.dart';

@JsonSerializable()
class TodayFeedingItem {
  const TodayFeedingItem({
    required this.routineId,
    required this.petId,
    required this.petName,
    required this.petCoat,
    required this.petPhoto,
    required this.time,
    required this.food,
    required this.amount,
    required this.unit,
    required this.mark,
  });
  
  factory TodayFeedingItem.fromJson(Map<String, Object?> json) => _$TodayFeedingItemFromJson(json);
  
  final String routineId;
  final String petId;
  final String petName;
  final Coat petCoat;
  final FileLink? petPhoto;
  final String time;
  final String? food;
  final double? amount;
  final PortionUnit? unit;
  final RoutineCompletionResponse? mark;

  Map<String, Object?> toJson() => _$TodayFeedingItemToJson(this);
}
