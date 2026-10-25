// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum DocumentType {
  @JsonValue('PassportPage')
  passportPage('PassportPage'),
  @JsonValue('VaccinationCertificate')
  vaccinationCertificate('VaccinationCertificate'),
  @JsonValue('LabResult')
  labResult('LabResult'),
  @JsonValue('Prescription')
  prescription('Prescription'),
  @JsonValue('Invoice')
  invoice('Invoice'),
  @JsonValue('Insurance')
  insurance('Insurance'),
  @JsonValue('Other')
  other('Other'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const DocumentType(this.json);

  factory DocumentType.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<DocumentType> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
