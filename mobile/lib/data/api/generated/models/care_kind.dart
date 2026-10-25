// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum CareKind {
  @JsonValue('Vaccination')
  vaccination('Vaccination'),
  @JsonValue('RabiesTiter')
  rabiesTiter('RabiesTiter'),
  @JsonValue('Deworming')
  deworming('Deworming'),
  @JsonValue('Echinococcus')
  echinococcus('Echinococcus'),
  @JsonValue('FleaTick')
  fleaTick('FleaTick'),
  @JsonValue('Heartworm')
  heartworm('Heartworm'),
  @JsonValue('VetExam')
  vetExam('VetExam'),
  @JsonValue('Dental')
  dental('Dental'),
  @JsonValue('Grooming')
  grooming('Grooming'),
  @JsonValue('Procedure')
  procedure('Procedure'),
  @JsonValue('Other')
  other('Other'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const CareKind(this.json);

  factory CareKind.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<CareKind> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
