// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'identifier_type.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'identifier_reading.g.dart';

@JsonSerializable()
class IdentifierReading {
  const IdentifierReading({
    required this.type,
    required this.code,
    required this.rawCode,
    required this.appliedOn,
    required this.location,
    required this.problem,
  });
  
  factory IdentifierReading.fromJson(Map<String, Object?> json) => _$IdentifierReadingFromJson(json);
  
  final IdentifierType type;
  final String code;
  final String rawCode;
	@DateOnlyConverter()
  final DateTime? appliedOn;
  final String? location;
  final String? problem;

  Map<String, Object?> toJson() => _$IdentifierReadingToJson(this);
}
