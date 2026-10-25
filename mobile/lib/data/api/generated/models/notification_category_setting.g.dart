// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_category_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationCategorySetting _$NotificationCategorySettingFromJson(
  Map<String, dynamic> json,
) => NotificationCategorySetting(
  category: NotificationCategory.fromJson(json['category']),
  enabled: json['enabled'] as bool,
);

Map<String, dynamic> _$NotificationCategorySettingToJson(
  NotificationCategorySetting instance,
) => <String, dynamic>{
  'category': _$NotificationCategoryEnumMap[instance.category]!,
  'enabled': instance.enabled,
};

const _$NotificationCategoryEnumMap = {
  NotificationCategory.feeding: 'Feeding',
  NotificationCategory.care: 'Care',
  NotificationCategory.appointments: 'Appointments',
  NotificationCategory.supplies: 'Supplies',
  NotificationCategory.$unknown: r'$unknown',
};
