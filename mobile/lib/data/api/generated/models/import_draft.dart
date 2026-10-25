// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'draft_identifier.dart';
import 'draft_passport.dart';
import 'draft_record.dart';
import 'draft_weight.dart';

part 'import_draft.g.dart';

@JsonSerializable()
class ImportDraft {
  const ImportDraft({
    required this.records,
    required this.identifiers,
    required this.passport,
    required this.weights,
  });
  
  factory ImportDraft.fromJson(Map<String, Object?> json) => _$ImportDraftFromJson(json);
  
  final List<DraftRecord> records;
  final List<DraftIdentifier> identifiers;
  final DraftPassport? passport;
  final List<DraftWeight> weights;

  Map<String, Object?> toJson() => _$ImportDraftToJson(this);
}
