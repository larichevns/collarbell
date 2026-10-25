// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'identifier_type.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'pet_identifier_request.g.dart';

@JsonSerializable()
class PetIdentifierRequest {
  const PetIdentifierRequest({
    required this.type,
    required this.code,
    required this.appliedOn,
    required this.readOn,
    required this.location,
  });
  
  factory PetIdentifierRequest.fromJson(Map<String, Object?> json) => _$PetIdentifierRequestFromJson(json);
  
  final IdentifierType type;
  final String code;
	@DateOnlyConverter()
  final DateTime? appliedOn;
	@DateOnlyConverter()
  final DateTime? readOn;
  final String? location;

  Map<String, Object?> toJson() => _$PetIdentifierRequestToJson(this);
}
