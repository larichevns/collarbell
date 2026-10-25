// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imported_weight_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImportedWeightRequest _$ImportedWeightRequestFromJson(
  Map<String, dynamic> json,
) => ImportedWeightRequest(
  measuredOn: const RequiredDateOnlyConverter().fromJson(
    json['measuredOn'] as String,
  ),
  weightKg: (json['weightKg'] as num).toDouble(),
);

Map<String, dynamic> _$ImportedWeightRequestToJson(
  ImportedWeightRequest instance,
) => <String, dynamic>{
  'measuredOn': const RequiredDateOnlyConverter().toJson(instance.measuredOn),
  'weightKg': instance.weightKg,
};
