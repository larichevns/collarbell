// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'draft_issue.dart';

part 'draft_warning.g.dart';

@JsonSerializable()
class DraftWarning {
  const DraftWarning({
    required this.field,
    required this.issue,
  });
  
  factory DraftWarning.fromJson(Map<String, Object?> json) => _$DraftWarningFromJson(json);
  
  final String field;
  final DraftIssue issue;

  Map<String, Object?> toJson() => _$DraftWarningToJson(this);
}
