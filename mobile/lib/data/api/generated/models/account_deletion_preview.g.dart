// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_deletion_preview.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountDeletionPreview _$AccountDeletionPreviewFromJson(
  Map<String, dynamic> json,
) => AccountDeletionPreview(
  households: (json['households'] as List<dynamic>)
      .map((e) => HouseholdDeletionOutcome.fromJson(e as Map<String, dynamic>))
      .toList(),
  plan: json['plan'] as String,
);

Map<String, dynamic> _$AccountDeletionPreviewToJson(
  AccountDeletionPreview instance,
) => <String, dynamic>{
  'households': instance.households.map((e) => e.toJson()).toList(),
  'plan': instance.plan,
};
