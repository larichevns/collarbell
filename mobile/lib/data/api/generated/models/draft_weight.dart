// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'draft_warning.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'draft_weight.g.dart';

@JsonSerializable()
class DraftWeight {
  const DraftWeight({
    required this.key,
    required this.measuredOn,
    required this.weightKg,
    required this.evidence,
    required this.page,
    required this.warnings,
    required this.duplicateOf,
    required this.selected,
  });
  
  factory DraftWeight.fromJson(Map<String, Object?> json) => _$DraftWeightFromJson(json);
  
  final int key;
	@DateOnlyConverter()
  final DateTime? measuredOn;
  final double? weightKg;
  final String? evidence;
  final int page;
  final List<DraftWarning> warnings;
  final String? duplicateOf;
  final bool selected;

  Map<String, Object?> toJson() => _$DraftWeightToJson(this);
}
