// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'identifier_type.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'pet_identifier_response.g.dart';

@JsonSerializable()
class PetIdentifierResponse {
  const PetIdentifierResponse({
    required this.id,
    required this.type,
    required this.code,
    required this.rawCode,
    required this.appliedOn,
    required this.readOn,
    required this.location,
  });
  
  factory PetIdentifierResponse.fromJson(Map<String, Object?> json) => _$PetIdentifierResponseFromJson(json);
  
  final String id;
  final IdentifierType type;
  final String code;
  final String rawCode;
	@DateOnlyConverter()
  final DateTime? appliedOn;
	@DateOnlyConverter()
  final DateTime? readOn;
  final String? location;

  Map<String, Object?> toJson() => _$PetIdentifierResponseToJson(this);
}
