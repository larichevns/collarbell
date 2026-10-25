// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_kind.dart';
import 'draft_warning.dart';
import 'vaccine_target.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'draft_record.g.dart';

@JsonSerializable()
class DraftRecord {
  const DraftRecord({
    required this.key,
    required this.kind,
    required this.title,
    required this.performedOn,
    required this.performedTime,
    required this.product,
    required this.manufacturer,
    required this.batchNumber,
    required this.validFrom,
    required this.validUntil,
    required this.targets,
    required this.veterinarian,
    required this.clinic,
    required this.weightKg,
    required this.evidence,
    required this.page,
    required this.warnings,
    required this.duplicateOf,
    required this.planId,
    required this.selected,
  });
  
  factory DraftRecord.fromJson(Map<String, Object?> json) => _$DraftRecordFromJson(json);
  
  final int key;
  final CareKind kind;
  final String? title;
	@DateOnlyConverter()
  final DateTime? performedOn;
  final String? performedTime;
  final String? product;
  final String? manufacturer;
  final String? batchNumber;
	@DateOnlyConverter()
  final DateTime? validFrom;
	@DateOnlyConverter()
  final DateTime? validUntil;
  final List<VaccineTarget> targets;
  final String? veterinarian;
  final String? clinic;
  final double? weightKg;
  final String? evidence;
  final int page;
  final List<DraftWarning> warnings;
  final String? duplicateOf;
  final String? planId;
  final bool selected;

  Map<String, Object?> toJson() => _$DraftRecordToJson(this);
}
