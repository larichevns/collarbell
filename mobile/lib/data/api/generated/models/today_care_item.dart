// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_kind.dart';
import 'care_status.dart';
import 'coat.dart';
import 'file_link.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'today_care_item.g.dart';

@JsonSerializable()
class TodayCareItem {
  const TodayCareItem({
    required this.planId,
    required this.petId,
    required this.petName,
    required this.petCoat,
    required this.petPhoto,
    required this.kind,
    required this.title,
    required this.nextDueOn,
    required this.status,
    required this.daysLeft,
  });
  
  factory TodayCareItem.fromJson(Map<String, Object?> json) => _$TodayCareItemFromJson(json);
  
  final String planId;
  final String petId;
  final String petName;
  final Coat petCoat;
  final FileLink? petPhoto;
  final CareKind kind;
  final String title;
	@RequiredDateOnlyConverter()
  final DateTime nextDueOn;
  final CareStatus status;
  final int daysLeft;

  Map<String, Object?> toJson() => _$TodayCareItemToJson(this);
}
