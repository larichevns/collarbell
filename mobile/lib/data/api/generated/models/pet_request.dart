// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'coat.dart';
import 'pet_identifier_request.dart';
import 'pet_status.dart';
import 'sex.dart';
import 'species.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'pet_request.g.dart';

@JsonSerializable()
class PetRequest {
  const PetRequest({
    required this.name,
    required this.species,
    required this.breed,
    required this.sex,
    required this.birthDate,
    required this.birthDateApproximate,
    required this.neutered,
    required this.neuteredOn,
    required this.color,
    required this.markings,
    required this.coat,
    required this.allergies,
    required this.notes,
    required this.status,
    required this.identifiers,
  });
  
  factory PetRequest.fromJson(Map<String, Object?> json) => _$PetRequestFromJson(json);
  
  final String name;
  final Species species;
  final String? breed;
  final Sex sex;
	@DateOnlyConverter()
  final DateTime? birthDate;
  final bool birthDateApproximate;
  final bool? neutered;
	@DateOnlyConverter()
  final DateTime? neuteredOn;
  final String? color;
  final String? markings;
  final Coat? coat;
  final String? allergies;
  final String? notes;
  final PetStatus? status;
  final List<PetIdentifierRequest>? identifiers;

  Map<String, Object?> toJson() => _$PetRequestToJson(this);
}
