// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'add_record_files_request.g.dart';

@JsonSerializable()
class AddRecordFilesRequest {
  const AddRecordFilesRequest({
    required this.fileIds,
  });
  
  factory AddRecordFilesRequest.fromJson(Map<String, Object?> json) => _$AddRecordFilesRequestFromJson(json);
  
  final List<String> fileIds;

  Map<String, Object?> toJson() => _$AddRecordFilesRequestToJson(this);
}
