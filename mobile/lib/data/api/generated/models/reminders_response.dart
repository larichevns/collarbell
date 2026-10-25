// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'reminder_response.dart';

part 'reminders_response.g.dart';

@JsonSerializable()
class RemindersResponse {
  const RemindersResponse({
    required this.upcoming,
    required this.recent,
  });
  
  factory RemindersResponse.fromJson(Map<String, Object?> json) => _$RemindersResponseFromJson(json);
  
  final List<ReminderResponse> upcoming;
  final List<ReminderResponse> recent;

  Map<String, Object?> toJson() => _$RemindersResponseToJson(this);
}
