// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'apply_passport_request.dart';
import 'imported_record_request.dart';
import 'imported_weight_request.dart';
import 'pet_identifier_request.dart';

part 'apply_import_request.g.dart';

@JsonSerializable()
class ApplyImportRequest {
  const ApplyImportRequest({
    required this.records,
    required this.identifiers,
    required this.passport,
    required this.keepPhotos,
    this.weights,
  });
  
  factory ApplyImportRequest.fromJson(Map<String, Object?> json) => _$ApplyImportRequestFromJson(json);
  
  final List<ImportedRecordRequest> records;
  final List<PetIdentifierRequest>? identifiers;
  final ApplyPassportRequest? passport;
  final bool keepPhotos;
  final List<ImportedWeightRequest>? weights;

  Map<String, Object?> toJson() => _$ApplyImportRequestToJson(this);
}
