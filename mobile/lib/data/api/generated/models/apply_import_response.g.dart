// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apply_import_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplyImportResponse _$ApplyImportResponseFromJson(Map<String, dynamic> json) =>
    ApplyImportResponse(
      recordIds: (json['recordIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      plansMoved: (json['plansMoved'] as num).toInt(),
      identifiersAdded: (json['identifiersAdded'] as num).toInt(),
      passportUpdated: json['passportUpdated'] as bool,
      documentId: json['documentId'] as String?,
      weightsAdded: (json['weightsAdded'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ApplyImportResponseToJson(
  ApplyImportResponse instance,
) => <String, dynamic>{
  'recordIds': instance.recordIds,
  'plansMoved': instance.plansMoved,
  'identifiersAdded': instance.identifiersAdded,
  'passportUpdated': instance.passportUpdated,
  'documentId': instance.documentId,
  'weightsAdded': instance.weightsAdded,
};
