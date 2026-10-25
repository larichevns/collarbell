// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum HouseholdFate {
  @JsonValue('Deleted')
  deleted('Deleted'),
  @JsonValue('Kept')
  kept('Kept'),
  @JsonValue('HandedOver')
  handedOver('HandedOver'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const HouseholdFate(this.json);

  factory HouseholdFate.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<HouseholdFate> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
