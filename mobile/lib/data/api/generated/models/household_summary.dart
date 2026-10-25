// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_role.dart';

part 'household_summary.g.dart';

@JsonSerializable()
class HouseholdSummary {
  const HouseholdSummary({
    required this.id,
    required this.name,
    required this.role,
    required this.timeZone,
    required this.memberCount,
  });
  
  factory HouseholdSummary.fromJson(Map<String, Object?> json) => _$HouseholdSummaryFromJson(json);
  
  final String id;
  final String name;
  final HouseholdRole role;
  final String timeZone;
  final int memberCount;

  Map<String, Object?> toJson() => _$HouseholdSummaryToJson(this);
}
