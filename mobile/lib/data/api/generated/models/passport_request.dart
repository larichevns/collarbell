// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'passport_contact_dto.dart';
import 'passport_model.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'passport_request.g.dart';

@JsonSerializable()
class PassportRequest {
  const PassportRequest({
    required this.model,
    required this.passportNumber,
    required this.issuingCountry,
    required this.issuedOn,
    required this.issuer,
    required this.owners,
    required this.notes,
  });
  
  factory PassportRequest.fromJson(Map<String, Object?> json) => _$PassportRequestFromJson(json);
  
  final PassportModel? model;
  final String? passportNumber;
  final String? issuingCountry;
	@DateOnlyConverter()
  final DateTime? issuedOn;
  final PassportContactDto? issuer;
  final List<PassportContactDto>? owners;
  final String? notes;

  Map<String, Object?> toJson() => _$PassportRequestToJson(this);
}
