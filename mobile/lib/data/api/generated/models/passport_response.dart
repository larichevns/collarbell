// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'passport_contact_dto.dart';
import 'passport_model.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'passport_response.g.dart';

@JsonSerializable()
class PassportResponse {
  const PassportResponse({
    required this.petId,
    required this.model,
    required this.passportNumber,
    required this.issuingCountry,
    required this.issuedOn,
    required this.issuer,
    required this.owners,
    required this.notes,
    required this.updatedAt,
  });
  
  factory PassportResponse.fromJson(Map<String, Object?> json) => _$PassportResponseFromJson(json);
  
  final String petId;
  final PassportModel? model;
  final String? passportNumber;
  final String? issuingCountry;
	@DateOnlyConverter()
  final DateTime? issuedOn;
  final PassportContactDto? issuer;
  final List<PassportContactDto> owners;
  final String? notes;
	@DateOnlyConverter()
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => _$PassportResponseToJson(this);
}
