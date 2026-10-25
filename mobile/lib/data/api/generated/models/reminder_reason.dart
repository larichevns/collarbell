// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ReminderReason {
  @JsonValue('NotNeeded')
  notNeeded('NotNeeded'),
  @JsonValue('NoRecipients')
  noRecipients('NoRecipients'),
  @JsonValue('PushNotConfigured')
  pushNotConfigured('PushNotConfigured'),
  @JsonValue('SendFailed')
  sendFailed('SendFailed'),
  /// The name has been replaced because it contains a keyword. Original name: `null`.
  @JsonValue(null)
  valueNull(null),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ReminderReason(this.json);

  factory ReminderReason.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<ReminderReason> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
