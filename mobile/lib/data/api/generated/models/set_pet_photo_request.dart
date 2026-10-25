// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'set_pet_photo_request.g.dart';

@JsonSerializable()
class SetPetPhotoRequest {
  const SetPetPhotoRequest({
    required this.fileId,
  });
  
  factory SetPetPhotoRequest.fromJson(Map<String, Object?> json) => _$SetPetPhotoRequestFromJson(json);
  
  final String fileId;

  Map<String, Object?> toJson() => _$SetPetPhotoRequestToJson(this);
}
