// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identifier_scan_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IdentifierScanRequest _$IdentifierScanRequestFromJson(
  Map<String, dynamic> json,
) => IdentifierScanRequest(
  fileIds: (json['fileIds'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$IdentifierScanRequestToJson(
  IdentifierScanRequest instance,
) => <String, dynamic>{'fileIds': instance.fileIds};
