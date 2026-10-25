// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'passport_contact_dto.g.dart';

@JsonSerializable()
class PassportContactDto {
  const PassportContactDto({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
  });
  
  factory PassportContactDto.fromJson(Map<String, Object?> json) => _$PassportContactDtoFromJson(json);
  
  final String? name;
  final String? address;
  final String? phone;
  final String? email;

  Map<String, Object?> toJson() => _$PassportContactDtoToJson(this);
}
