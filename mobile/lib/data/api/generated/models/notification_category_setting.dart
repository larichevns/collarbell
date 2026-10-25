// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'notification_category.dart';

part 'notification_category_setting.g.dart';

@JsonSerializable()
class NotificationCategorySetting {
  const NotificationCategorySetting({
    required this.category,
    required this.enabled,
  });
  
  factory NotificationCategorySetting.fromJson(Map<String, Object?> json) => _$NotificationCategorySettingFromJson(json);
  
  final NotificationCategory category;
  final bool enabled;

  Map<String, Object?> toJson() => _$NotificationCategorySettingToJson(this);
}
