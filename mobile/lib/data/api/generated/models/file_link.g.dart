// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileLink _$FileLinkFromJson(Map<String, dynamic> json) => FileLink(
  id: json['id'] as String,
  contentType: json['contentType'] as String,
  sizeBytes: (json['sizeBytes'] as num).toInt(),
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  url: json['url'] as String,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  expiresAt: const RequiredDateOnlyConverter().fromJson(
    json['expiresAt'] as String,
  ),
);

Map<String, dynamic> _$FileLinkToJson(FileLink instance) => <String, dynamic>{
  'id': instance.id,
  'contentType': instance.contentType,
  'sizeBytes': instance.sizeBytes,
  'width': instance.width,
  'height': instance.height,
  'url': instance.url,
  'thumbnailUrl': instance.thumbnailUrl,
  'expiresAt': const RequiredDateOnlyConverter().toJson(instance.expiresAt),
};
