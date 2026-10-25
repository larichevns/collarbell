// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'plan_kind.dart';
import 'plan_source.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'plan_response.g.dart';

@JsonSerializable()
class PlanResponse {
  const PlanResponse({
    required this.plan,
    required this.source,
    required this.expiresAt,
    required this.aiPhotosPerMonth,
    required this.aiPhotosUsed,
    required this.resetsAt,
    required this.premiumAiPhotosPerMonth,
  });
  
  factory PlanResponse.fromJson(Map<String, Object?> json) => _$PlanResponseFromJson(json);
  
  final PlanKind plan;
  final PlanSource? source;
	@DateOnlyConverter()
  final DateTime? expiresAt;
  final int aiPhotosPerMonth;
  final int aiPhotosUsed;
	@RequiredDateOnlyConverter()
  final DateTime resetsAt;
  final int premiumAiPhotosPerMonth;

  Map<String, Object?> toJson() => _$PlanResponseToJson(this);
}
