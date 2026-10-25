// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'notification_category.dart';
import 'reminder_reason.dart';
import 'reminder_source.dart';
import 'reminder_status.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'reminder_response.g.dart';

@JsonSerializable()
class ReminderResponse {
  const ReminderResponse({
    required this.id,
    required this.category,
    required this.source,
    required this.sourceId,
    required this.subject,
    required this.fireAt,
    required this.status,
    required this.reason,
    required this.sentAt,
  });
  
  factory ReminderResponse.fromJson(Map<String, Object?> json) => _$ReminderResponseFromJson(json);
  
  final String id;
  final NotificationCategory category;
  final ReminderSource source;
  final String sourceId;
  final String subject;
	@RequiredDateOnlyConverter()
  final DateTime fireAt;
  final ReminderStatus status;
  final ReminderReason? reason;
	@DateOnlyConverter()
  final DateTime? sentAt;

  Map<String, Object?> toJson() => _$ReminderResponseToJson(this);
}
