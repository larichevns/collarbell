// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum TestPushProblem {
  @JsonValue('NotConfigured')
  notConfigured('NotConfigured'),
  @JsonValue('NoDevices')
  noDevices('NoDevices'),
  @JsonValue('Failed')
  failed('Failed'),
  /// The name has been replaced because it contains a keyword. Original name: `null`.
  @JsonValue(null)
  valueNull(null),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const TestPushProblem(this.json);

  factory TestPushProblem.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<TestPushProblem> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
