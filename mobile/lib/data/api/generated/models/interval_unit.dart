// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum IntervalUnit {
  @JsonValue('Day')
  day('Day'),
  @JsonValue('Week')
  week('Week'),
  @JsonValue('Month')
  month('Month'),
  @JsonValue('Year')
  year('Year'),
  /// The name has been replaced because it contains a keyword. Original name: `null`.
  @JsonValue(null)
  valueNull(null),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const IntervalUnit(this.json);

  factory IntervalUnit.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<IntervalUnit> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
