// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weight_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeightRequest _$WeightRequestFromJson(Map<String, dynamic> json) =>
    WeightRequest(
      measuredOn: const RequiredDateOnlyConverter().fromJson(
        json['measuredOn'] as String,
      ),
      weightKg: (json['weightKg'] as num).toDouble(),
      bcs: (json['bcs'] as num?)?.toInt(),
      bcsScale: (json['bcsScale'] as num?)?.toInt(),
      note: json['note'] as String?,
      requestId: json['requestId'] as String?,
    );

Map<String, dynamic> _$WeightRequestToJson(
  WeightRequest instance,
) => <String, dynamic>{
  'measuredOn': const RequiredDateOnlyConverter().toJson(instance.measuredOn),
  'weightKg': instance.weightKg,
  'bcs': instance.bcs,
  'bcsScale': instance.bcsScale,
  'note': instance.note,
  'requestId': instance.requestId,
};
