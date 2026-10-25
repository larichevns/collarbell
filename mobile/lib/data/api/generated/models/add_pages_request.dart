// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'add_pages_request.g.dart';

@JsonSerializable()
class AddPagesRequest {
  const AddPagesRequest({
    required this.fileIds,
  });
  
  factory AddPagesRequest.fromJson(Map<String, Object?> json) => _$AddPagesRequestFromJson(json);
  
  final List<String> fileIds;

  Map<String, Object?> toJson() => _$AddPagesRequestToJson(this);
}
