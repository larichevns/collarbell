// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_record_files_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddRecordFilesRequest _$AddRecordFilesRequestFromJson(
  Map<String, dynamic> json,
) => AddRecordFilesRequest(
  fileIds: (json['fileIds'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$AddRecordFilesRequestToJson(
  AddRecordFilesRequest instance,
) => <String, dynamic>{'fileIds': instance.fileIds};
