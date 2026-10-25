// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_kind.dart';
import 'interval_unit.dart';
import 'species.dart';
import 'vaccine_target.dart';

part 'care_preset_response.g.dart';

@JsonSerializable()
class CarePresetResponse {
  const CarePresetResponse({
    required this.code,
    required this.species,
    required this.kind,
    required this.title,
    required this.intervalValue,
    required this.intervalUnit,
    required this.targets,
    required this.dogOnly,
    required this.note,
  });
  
  factory CarePresetResponse.fromJson(Map<String, Object?> json) => _$CarePresetResponseFromJson(json);
  
  final String code;
  final Species? species;
  final CareKind kind;
  final String title;
  final int? intervalValue;
  final IntervalUnit? intervalUnit;
  final List<VaccineTarget> targets;
  final bool dogOnly;
  final String? note;

  Map<String, Object?> toJson() => _$CarePresetResponseToJson(this);
}
