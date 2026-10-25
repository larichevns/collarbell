// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_response.dart';
import 'household_summary.dart';

part 'me_response.g.dart';

@JsonSerializable()
class MeResponse {
  const MeResponse({
    required this.id,
    required this.email,
    required this.displayName,
    required this.locale,
    required this.timeZone,
    required this.household,
    required this.households,
  });
  
  factory MeResponse.fromJson(Map<String, Object?> json) => _$MeResponseFromJson(json);
  
  final String id;
  final String? email;
  final String? displayName;
  final String locale;
  final String timeZone;
  final HouseholdResponse household;
  final List<HouseholdSummary> households;

  Map<String, Object?> toJson() => _$MeResponseToJson(this);
}
