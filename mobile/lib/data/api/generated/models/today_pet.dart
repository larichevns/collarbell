// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'coat.dart';
import 'file_link.dart';

part 'today_pet.g.dart';

@JsonSerializable()
class TodayPet {
  const TodayPet({
    required this.id,
    required this.name,
    required this.coat,
    required this.photo,
  });
  
  factory TodayPet.fromJson(Map<String, Object?> json) => _$TodayPetFromJson(json);
  
  final String id;
  final String name;
  final Coat coat;
  final FileLink? photo;

  Map<String, Object?> toJson() => _$TodayPetToJson(this);
}
