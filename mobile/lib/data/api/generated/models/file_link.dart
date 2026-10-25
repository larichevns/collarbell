// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'file_link.g.dart';

@JsonSerializable()
class FileLink {
  const FileLink({
    required this.id,
    required this.contentType,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.url,
    required this.thumbnailUrl,
    required this.expiresAt,
  });
  
  factory FileLink.fromJson(Map<String, Object?> json) => _$FileLinkFromJson(json);
  
  final String id;
  final String contentType;
  final int sizeBytes;
  final int? width;
  final int? height;
  final String url;
  final String? thumbnailUrl;
	@RequiredDateOnlyConverter()
  final DateTime expiresAt;

  Map<String, Object?> toJson() => _$FileLinkToJson(this);
}
