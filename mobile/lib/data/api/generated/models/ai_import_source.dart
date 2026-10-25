// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum AiImportSource {
  @JsonValue('PassportPages')
  passportPages('PassportPages'),
  @JsonValue('VetDocument')
  vetDocument('VetDocument'),
  @JsonValue('Text')
  text('Text'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const AiImportSource(this.json);

  factory AiImportSource.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<AiImportSource> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
