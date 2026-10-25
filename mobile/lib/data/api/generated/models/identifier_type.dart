// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum IdentifierType {
  @JsonValue('IsoChip')
  isoChip('IsoChip'),
  @JsonValue('LegacyChip')
  legacyChip('LegacyChip'),
  @JsonValue('Tattoo')
  tattoo('Tattoo'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const IdentifierType(this.json);

  factory IdentifierType.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<IdentifierType> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
