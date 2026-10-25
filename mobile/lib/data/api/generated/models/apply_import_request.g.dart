// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apply_import_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplyImportRequest _$ApplyImportRequestFromJson(
  Map<String, dynamic> json,
) => ApplyImportRequest(
  records: (json['records'] as List<dynamic>)
      .map((e) => ImportedRecordRequest.fromJson(e as Map<String, dynamic>))
      .toList(),
  identifiers: (json['identifiers'] as List<dynamic>?)
      ?.map((e) => PetIdentifierRequest.fromJson(e as Map<String, dynamic>))
      .toList(),
  passport: json['passport'] == null
      ? null
      : ApplyPassportRequest.fromJson(json['passport'] as Map<String, dynamic>),
  keepPhotos: json['keepPhotos'] as bool,
  weights: (json['weights'] as List<dynamic>?)
      ?.map((e) => ImportedWeightRequest.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ApplyImportRequestToJson(ApplyImportRequest instance) =>
    <String, dynamic>{
      'records': instance.records.map((e) => e.toJson()).toList(),
      'identifiers': instance.identifiers?.map((e) => e.toJson()).toList(),
      'passport': instance.passport?.toJson(),
      'keepPhotos': instance.keepPhotos,
      'weights': instance.weights?.map((e) => e.toJson()).toList(),
    };
