// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'draft_warning.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'draft_passport.g.dart';

@JsonSerializable()
class DraftPassport {
  const DraftPassport({
    required this.passportNumber,
    required this.issuingCountry,
    required this.issuedOn,
    required this.evidence,
    required this.page,
    required this.warnings,
    required this.selected,
  });
  
  factory DraftPassport.fromJson(Map<String, Object?> json) => _$DraftPassportFromJson(json);
  
  final String? passportNumber;
  final String? issuingCountry;
	@DateOnlyConverter()
  final DateTime? issuedOn;
  final String? evidence;
  final int page;
  final List<DraftWarning> warnings;
  final bool selected;

  Map<String, Object?> toJson() => _$DraftPassportToJson(this);
}
