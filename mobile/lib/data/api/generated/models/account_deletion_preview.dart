// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_deletion_outcome.dart';

part 'account_deletion_preview.g.dart';

@JsonSerializable()
class AccountDeletionPreview {
  const AccountDeletionPreview({
    required this.households,
    required this.plan,
  });
  
  factory AccountDeletionPreview.fromJson(Map<String, Object?> json) => _$AccountDeletionPreviewFromJson(json);
  
  final List<HouseholdDeletionOutcome> households;
  final String plan;

  Map<String, Object?> toJson() => _$AccountDeletionPreviewToJson(this);
}
