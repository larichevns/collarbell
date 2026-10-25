// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum VaccineTarget {
  @JsonValue('Rabies')
  rabies('Rabies'),
  @JsonValue('Fpv')
  fpv('Fpv'),
  @JsonValue('Fhv1')
  fhv1('Fhv1'),
  @JsonValue('Fcv')
  fcv('Fcv'),
  @JsonValue('Felv')
  felv('Felv'),
  @JsonValue('Chlamydia')
  chlamydia('Chlamydia'),
  @JsonValue('Cdv')
  cdv('Cdv'),
  @JsonValue('Cav2')
  cav2('Cav2'),
  @JsonValue('Cpv2')
  cpv2('Cpv2'),
  @JsonValue('Cpiv')
  cpiv('Cpiv'),
  @JsonValue('Lepto')
  lepto('Lepto'),
  @JsonValue('Bordetella')
  bordetella('Bordetella'),
  @JsonValue('Lyme')
  lyme('Lyme'),
  @JsonValue('CanineInfluenza')
  canineInfluenza('CanineInfluenza'),
  @JsonValue('Leishmania')
  leishmania('Leishmania'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const VaccineTarget(this.json);

  factory VaccineTarget.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<VaccineTarget> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
