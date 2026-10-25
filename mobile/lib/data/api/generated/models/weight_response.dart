// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'weight_source.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'weight_response.g.dart';

@JsonSerializable()
class WeightResponse {
  const WeightResponse({
    required this.id,
    required this.petId,
    required this.source,
    required this.measuredOn,
    required this.weightKg,
    required this.bcs,
    required this.bcsScale,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory WeightResponse.fromJson(Map<String, Object?> json) => _$WeightResponseFromJson(json);
  
  final String id;
  final String petId;
  final WeightSource source;
	@RequiredDateOnlyConverter()
  final DateTime measuredOn;
  final double weightKg;
  final int? bcs;
  final int? bcsScale;
  final String? note;
	@RequiredDateOnlyConverter()
  final DateTime createdAt;
	@RequiredDateOnlyConverter()
  final DateTime updatedAt;

  Map<String, Object?> toJson() => _$WeightResponseToJson(this);
}
