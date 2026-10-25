// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imported_record_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImportedRecordRequest _$ImportedRecordRequestFromJson(
  Map<String, dynamic> json,
) => ImportedRecordRequest(
  record: CareRecordRequest.fromJson(json['record'] as Map<String, dynamic>),
  planId: json['planId'] as String?,
);

Map<String, dynamic> _$ImportedRecordRequestToJson(
  ImportedRecordRequest instance,
) => <String, dynamic>{
  'record': instance.record.toJson(),
  'planId': instance.planId,
};
