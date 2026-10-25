// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_household_request.g.dart';

@JsonSerializable()
class CreateHouseholdRequest {
  const CreateHouseholdRequest({
    required this.name,
  });
  
  factory CreateHouseholdRequest.fromJson(Map<String, Object?> json) => _$CreateHouseholdRequestFromJson(json);
  
  final String? name;

  Map<String, Object?> toJson() => _$CreateHouseholdRequestToJson(this);
}
