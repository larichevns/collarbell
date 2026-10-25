// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum AppEventKind {
  @JsonValue('Screen')
  screen('Screen'),
  @JsonValue('Action')
  action('Action'),
  @JsonValue('Error')
  error('Error'),
  @JsonValue('Crash')
  crash('Crash'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const AppEventKind(this.json);

  factory AppEventKind.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<AppEventKind> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
