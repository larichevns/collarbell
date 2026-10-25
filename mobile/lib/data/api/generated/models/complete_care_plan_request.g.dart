// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_care_plan_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompleteCarePlanRequest _$CompleteCarePlanRequestFromJson(
  Map<String, dynamic> json,
) => CompleteCarePlanRequest(
  performedOn: const RequiredDateOnlyConverter().fromJson(
    json['performedOn'] as String,
  ),
  performedTime: json['performedTime'] as String?,
  product: json['product'] as String?,
  manufacturer: json['manufacturer'] as String?,
  batchNumber: json['batchNumber'] as String?,
  validFrom: const DateOnlyConverter().fromJson(json['validFrom'] as String?),
  validUntil: const DateOnlyConverter().fromJson(json['validUntil'] as String?),
  clinic: json['clinic'] as String?,
  veterinarian: json['veterinarian'] as String?,
  notes: json['notes'] as String?,
  nextDueOn: const DateOnlyConverter().fromJson(json['nextDueOn'] as String?),
  requestId: json['requestId'] as String?,
);

Map<String, dynamic> _$CompleteCarePlanRequestToJson(
  CompleteCarePlanRequest instance,
) => <String, dynamic>{
  'performedOn': const RequiredDateOnlyConverter().toJson(instance.performedOn),
  'performedTime': instance.performedTime,
  'product': instance.product,
  'manufacturer': instance.manufacturer,
  'batchNumber': instance.batchNumber,
  'validFrom': const DateOnlyConverter().toJson(instance.validFrom),
  'validUntil': const DateOnlyConverter().toJson(instance.validUntil),
  'clinic': instance.clinic,
  'veterinarian': instance.veterinarian,
  'notes': instance.notes,
  'nextDueOn': const DateOnlyConverter().toJson(instance.nextDueOn),
  'requestId': instance.requestId,
};
