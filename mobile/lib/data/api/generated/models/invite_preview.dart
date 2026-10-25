// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'household_role.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'invite_preview.g.dart';

@JsonSerializable()
class InvitePreview {
  const InvitePreview({
    required this.householdName,
    required this.invitedBy,
    required this.role,
    required this.expiresAt,
    required this.alreadyMember,
  });
  
  factory InvitePreview.fromJson(Map<String, Object?> json) => _$InvitePreviewFromJson(json);
  
  final String householdName;
  final String? invitedBy;
  final HouseholdRole role;
	@RequiredDateOnlyConverter()
  final DateTime expiresAt;
  final bool alreadyMember;

  Map<String, Object?> toJson() => _$InvitePreviewToJson(this);
}
