// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'draft_warning.dart';
import 'identifier_type.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'draft_identifier.g.dart';

@JsonSerializable()
class DraftIdentifier {
  const DraftIdentifier({
    required this.key,
    required this.type,
    required this.code,
    required this.appliedOn,
    required this.location,
    required this.evidence,
    required this.page,
    required this.warnings,
    required this.selected,
  });
  
  factory DraftIdentifier.fromJson(Map<String, Object?> json) => _$DraftIdentifierFromJson(json);
  
  final int key;
  final IdentifierType type;
  final String? code;
	@DateOnlyConverter()
  final DateTime? appliedOn;
  final String? location;
  final String? evidence;
  final int page;
  final List<DraftWarning> warnings;
  final bool selected;

  Map<String, Object?> toJson() => _$DraftIdentifierToJson(this);
}
