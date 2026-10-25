// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum SupplyCategory {
  @JsonValue('DryFood')
  dryFood('DryFood'),
  @JsonValue('WetFood')
  wetFood('WetFood'),
  @JsonValue('Treats')
  treats('Treats'),
  @JsonValue('Litter')
  litter('Litter'),
  @JsonValue('Medication')
  medication('Medication'),
  @JsonValue('Other')
  other('Other'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const SupplyCategory(this.json);

  factory SupplyCategory.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<SupplyCategory> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
