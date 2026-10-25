// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'imported_weight_request.g.dart';

@JsonSerializable()
class ImportedWeightRequest {
  const ImportedWeightRequest({
    required this.measuredOn,
    required this.weightKg,
  });
  
  factory ImportedWeightRequest.fromJson(Map<String, Object?> json) => _$ImportedWeightRequestFromJson(json);
  
	@RequiredDateOnlyConverter()
  final DateTime measuredOn;
  final double weightKg;

  Map<String, Object?> toJson() => _$ImportedWeightRequestToJson(this);
}
