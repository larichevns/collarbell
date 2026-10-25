// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ReminderStatus {
  @JsonValue('Pending')
  pending('Pending'),
  @JsonValue('Sent')
  sent('Sent'),
  @JsonValue('Skipped')
  skipped('Skipped'),
  @JsonValue('Expired')
  expired('Expired'),
  @JsonValue('Failed')
  failed('Failed'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ReminderStatus(this.json);

  factory ReminderStatus.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<ReminderStatus> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
