// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_pages_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddPagesRequest _$AddPagesRequestFromJson(Map<String, dynamic> json) =>
    AddPagesRequest(
      fileIds: (json['fileIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$AddPagesRequestToJson(AddPagesRequest instance) =>
    <String, dynamic>{'fileIds': instance.fileIds};
