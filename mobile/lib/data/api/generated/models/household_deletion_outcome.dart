// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_fate.dart';
import 'household_role.dart';

part 'household_deletion_outcome.g.dart';

@JsonSerializable()
class HouseholdDeletionOutcome {
  const HouseholdDeletionOutcome({
    required this.id,
    required this.name,
    required this.role,
    required this.fate,
    required this.pets,
    required this.others,
    required this.newOwner,
  });
  
  factory HouseholdDeletionOutcome.fromJson(Map<String, Object?> json) => _$HouseholdDeletionOutcomeFromJson(json);
  
  final String id;
  final String name;
  final HouseholdRole role;
  final HouseholdFate fate;
  final int pets;
  final int others;
  final String? newOwner;

  Map<String, Object?> toJson() => _$HouseholdDeletionOutcomeToJson(this);
}
