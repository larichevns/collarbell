// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DraftRecord _$DraftRecordFromJson(Map<String, dynamic> json) => DraftRecord(
  key: (json['key'] as num).toInt(),
  kind: CareKind.fromJson(json['kind']),
  title: json['title'] as String?,
  performedOn: const DateOnlyConverter().fromJson(
    json['performedOn'] as String?,
  ),
  performedTime: json['performedTime'] as String?,
  product: json['product'] as String?,
  manufacturer: json['manufacturer'] as String?,
  batchNumber: json['batchNumber'] as String?,
  validFrom: const DateOnlyConverter().fromJson(json['validFrom'] as String?),
  validUntil: const DateOnlyConverter().fromJson(json['validUntil'] as String?),
  targets: (json['targets'] as List<dynamic>)
      .map(VaccineTarget.fromJson)
      .toList(),
  veterinarian: json['veterinarian'] as String?,
  clinic: json['clinic'] as String?,
  weightKg: (json['weightKg'] as num?)?.toDouble(),
  evidence: json['evidence'] as String?,
  page: (json['page'] as num).toInt(),
  warnings: (json['warnings'] as List<dynamic>)
      .map((e) => DraftWarning.fromJson(e as Map<String, dynamic>))
      .toList(),
  duplicateOf: json['duplicateOf'] as String?,
  planId: json['planId'] as String?,
  selected: json['selected'] as bool,
);

Map<String, dynamic> _$DraftRecordToJson(
  DraftRecord instance,
) => <String, dynamic>{
  'key': instance.key,
  'kind': _$CareKindEnumMap[instance.kind]!,
  'title': instance.title,
  'performedOn': const DateOnlyConverter().toJson(instance.performedOn),
  'performedTime': instance.performedTime,
  'product': instance.product,
  'manufacturer': instance.manufacturer,
  'batchNumber': instance.batchNumber,
  'validFrom': const DateOnlyConverter().toJson(instance.validFrom),
  'validUntil': const DateOnlyConverter().toJson(instance.validUntil),
  'targets': instance.targets.map((e) => _$VaccineTargetEnumMap[e]!).toList(),
  'veterinarian': instance.veterinarian,
  'clinic': instance.clinic,
  'weightKg': instance.weightKg,
  'evidence': instance.evidence,
  'page': instance.page,
  'warnings': instance.warnings.map((e) => e.toJson()).toList(),
  'duplicateOf': instance.duplicateOf,
  'planId': instance.planId,
  'selected': instance.selected,
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
