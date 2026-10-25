// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identifier_scan_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IdentifierScanResponse _$IdentifierScanResponseFromJson(
  Map<String, dynamic> json,
) => IdentifierScanResponse(
  identifiers: (json['identifiers'] as List<dynamic>)
      .map((e) => IdentifierReading.fromJson(e as Map<String, dynamic>))
      .toList(),
  model: json['model'] as String,
);

Map<String, dynamic> _$IdentifierScanResponseToJson(
  IdentifierScanResponse instance,
) => <String, dynamic>{
  'identifiers': instance.identifiers.map((e) => e.toJson()).toList(),
  'model': instance.model,
};
