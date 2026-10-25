// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'care_record_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CareRecordRequest _$CareRecordRequestFromJson(
  Map<String, dynamic> json,
) => CareRecordRequest(
  kind: CareKind.fromJson(json['kind']),
  title: json['title'] as String,
  performedOn: const RequiredDateOnlyConverter().fromJson(
    json['performedOn'] as String,
  ),
  performedTime: json['performedTime'] as String?,
  product: json['product'] as String?,
  manufacturer: json['manufacturer'] as String?,
  batchNumber: json['batchNumber'] as String?,
  validFrom: const DateOnlyConverter().fromJson(json['validFrom'] as String?),
  validUntil: const DateOnlyConverter().fromJson(json['validUntil'] as String?),
  targets: (json['targets'] as List<dynamic>?)
      ?.map(VaccineTarget.fromJson)
      .toList(),
  clinic: json['clinic'] as String?,
  veterinarian: json['veterinarian'] as String?,
  weightKg: (json['weightKg'] as num?)?.toDouble(),
  details: json['details'] == null
      ? null
      : CareRecordDetailsDto.fromJson(json['details'] as Map<String, dynamic>),
  notes: json['notes'] as String?,
  requestId: json['requestId'] as String?,
);

Map<String, dynamic> _$CareRecordRequestToJson(
  CareRecordRequest instance,
) => <String, dynamic>{
  'kind': _$CareKindEnumMap[instance.kind]!,
  'title': instance.title,
  'performedOn': const RequiredDateOnlyConverter().toJson(instance.performedOn),
  'performedTime': instance.performedTime,
  'product': instance.product,
  'manufacturer': instance.manufacturer,
  'batchNumber': instance.batchNumber,
  'validFrom': const DateOnlyConverter().toJson(instance.validFrom),
  'validUntil': const DateOnlyConverter().toJson(instance.validUntil),
  'targets': instance.targets?.map((e) => _$VaccineTargetEnumMap[e]!).toList(),
  'clinic': instance.clinic,
  'veterinarian': instance.veterinarian,
  'weightKg': instance.weightKg,
  'details': instance.details?.toJson(),
  'notes': instance.notes,
  'requestId': instance.requestId,
};

const _$CareKindEnumMap = {
  CareKind.vaccination: 'Vaccination',
  CareKind.rabiesTiter: 'RabiesTiter',
  CareKind.deworming: 'Deworming',
  CareKind.echinococcus: 'Echinococcus',
  CareKind.fleaTick: 'FleaTick',
  CareKind.heartworm: 'Heartworm',
  CareKind.vetExam: 'VetExam',
  CareKind.dental: 'Dental',
  CareKind.grooming: 'Grooming',
  CareKind.procedure: 'Procedure',
  CareKind.other: 'Other',
  CareKind.$unknown: r'$unknown',
};

const _$VaccineTargetEnumMap = {
  VaccineTarget.rabies: 'Rabies',
  VaccineTarget.fpv: 'Fpv',
  VaccineTarget.fhv1: 'Fhv1',
  VaccineTarget.fcv: 'Fcv',
  VaccineTarget.felv: 'Felv',
  VaccineTarget.chlamydia: 'Chlamydia',
  VaccineTarget.cdv: 'Cdv',
  VaccineTarget.cav2: 'Cav2',
  VaccineTarget.cpv2: 'Cpv2',
  VaccineTarget.cpiv: 'Cpiv',
  VaccineTarget.lepto: 'Lepto',
  VaccineTarget.bordetella: 'Bordetella',
  VaccineTarget.lyme: 'Lyme',
  VaccineTarget.canineInfluenza: 'CanineInfluenza',
  VaccineTarget.leishmania: 'Leishmania',
  VaccineTarget.$unknown: r'$unknown',
};
