// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'care_kind.dart';
import 'care_record_details_dto.dart';
import 'file_link.dart';
import 'record_source.dart';
import 'vaccine_target.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'care_record_response.g.dart';

@JsonSerializable()
class CareRecordResponse {
  const CareRecordResponse({
    required this.id,
    required this.petId,
    required this.planId,
    required this.kind,
    required this.title,
    required this.performedOn,
    required this.performedTime,
    required this.product,
    required this.manufacturer,
    required this.batchNumber,
    required this.validFrom,
    required this.validUntil,
    required this.targets,
    required this.clinic,
    required this.veterinarian,
    required this.weightKg,
    required this.details,
    required this.notes,
    required this.source,
    required this.files,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory CareRecordResponse.fromJson(Map<String, Object?> json) => _$CareRecordResponseFromJson(json);
  
  final String id;
  final String petId;
  final String? planId;
  final CareKind kind;
  final String title;
	@RequiredDateOnlyConverter()
  final DateTime performedOn;
  final String? performedTime;
  final String? product;
  final String? manufacturer;
  final String? batchNumber;
	@DateOnlyConverter()
  final DateTime? validFrom;
	@DateOnlyConverter()
  final DateTime? validUntil;
  final List<VaccineTarget> targets;
  final String? clinic;
  final String? veterinarian;
  final double? weightKg;
  final CareRecordDetailsDto? details;
  final String? notes;
  final RecordSource source;
  final List<FileLink> files;
	@RequiredDateOnlyConverter()
  final DateTime createdAt;
	@RequiredDateOnlyConverter()
  final DateTime updatedAt;

  Map<String, Object?> toJson() => _$CareRecordResponseToJson(this);
}
