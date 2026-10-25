// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReminderResponse _$ReminderResponseFromJson(Map<String, dynamic> json) =>
    ReminderResponse(
      id: json['id'] as String,
      category: NotificationCategory.fromJson(json['category']),
      source: ReminderSource.fromJson(json['source']),
      sourceId: json['sourceId'] as String,
      subject: json['subject'] as String,
      fireAt: const RequiredDateOnlyConverter().fromJson(
        json['fireAt'] as String,
      ),
      status: ReminderStatus.fromJson(json['status']),
      reason: json['reason'] == null
          ? null
          : ReminderReason.fromJson(json['reason']),
      sentAt: const DateOnlyConverter().fromJson(json['sentAt'] as String?),
    );

Map<String, dynamic> _$ReminderResponseToJson(ReminderResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': _$NotificationCategoryEnumMap[instance.category]!,
      'source': _$ReminderSourceEnumMap[instance.source]!,
      'sourceId': instance.sourceId,
      'subject': instance.subject,
      'fireAt': const RequiredDateOnlyConverter().toJson(instance.fireAt),
      'status': _$ReminderStatusEnumMap[instance.status]!,
      'reason': _$ReminderReasonEnumMap[instance.reason],
      'sentAt': const DateOnlyConverter().toJson(instance.sentAt),
    };

const _$NotificationCategoryEnumMap = {
  NotificationCategory.feeding: 'Feeding',
  NotificationCategory.care: 'Care',
  NotificationCategory.appointments: 'Appointments',
  NotificationCategory.supplies: 'Supplies',
  NotificationCategory.$unknown: r'$unknown',
};

const _$ReminderSourceEnumMap = {
  ReminderSource.carePlan: 'CarePlan',
  ReminderSource.appointment: 'Appointment',
  ReminderSource.feeding: 'Feeding',
  ReminderSource.supply: 'Supply',
  ReminderSource.$unknown: r'$unknown',
};

const _$ReminderStatusEnumMap = {
  ReminderStatus.pending: 'Pending',
  ReminderStatus.sent: 'Sent',
  ReminderStatus.skipped: 'Skipped',
  ReminderStatus.expired: 'Expired',
  ReminderStatus.failed: 'Failed',
  ReminderStatus.$unknown: r'$unknown',
};

const _$ReminderReasonEnumMap = {
  ReminderReason.notNeeded: 'NotNeeded',
  ReminderReason.noRecipients: 'NoRecipients',
  ReminderReason.pushNotConfigured: 'PushNotConfigured',
  ReminderReason.sendFailed: 'SendFailed',
  ReminderReason.valueNull: null,
  ReminderReason.$unknown: r'$unknown',
};
