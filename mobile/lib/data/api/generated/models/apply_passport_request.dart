// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'apply_passport_request.g.dart';

@JsonSerializable()
class ApplyPassportRequest {
  const ApplyPassportRequest({
    required this.passportNumber,
    required this.issuingCountry,
    required this.issuedOn,
  });
  
  factory ApplyPassportRequest.fromJson(Map<String, Object?> json) => _$ApplyPassportRequestFromJson(json);
  
  final String? passportNumber;
  final String? issuingCountry;
	@DateOnlyConverter()
  final DateTime? issuedOn;

  Map<String, Object?> toJson() => _$ApplyPassportRequestToJson(this);
}
