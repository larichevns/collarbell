// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'weight_request.g.dart';

@JsonSerializable()
class WeightRequest {
  const WeightRequest({
    required this.measuredOn,
    required this.weightKg,
    required this.bcs,
    required this.bcsScale,
    required this.note,
    required this.requestId,
  });
  
  factory WeightRequest.fromJson(Map<String, Object?> json) => _$WeightRequestFromJson(json);
  
	@RequiredDateOnlyConverter()
  final DateTime measuredOn;
  final double weightKg;
  final int? bcs;
  final int? bcsScale;
  final String? note;
  final String? requestId;

  Map<String, Object?> toJson() => _$WeightRequestToJson(this);
}
