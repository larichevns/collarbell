// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'care_plan_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CarePlanRequest _$CarePlanRequestFromJson(Map<String, dynamic> json) =>
    CarePlanRequest(
      kind: CareKind.fromJson(json['kind']),
      title: json['title'] as String,
      intervalValue: (json['intervalValue'] as num?)?.toInt(),
      intervalUnit: json['intervalUnit'] == null
          ? null
          : IntervalUnit.fromJson(json['intervalUnit']),
      nextDueOn: const RequiredDateOnlyConverter().fromJson(
        json['nextDueOn'] as String,
      ),
      remindOffsetsDays: (json['remindOffsetsDays'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      defaultProduct: json['defaultProduct'] as String?,
      targets: (json['targets'] as List<dynamic>?)
          ?.map(VaccineTarget.fromJson)
          .toList(),
      presetCode: json['presetCode'] as String?,
      notes: json['notes'] as String?,
      active: json['active'] as bool?,
      requestId: json['requestId'] as String?,
    );

Map<String, dynamic> _$CarePlanRequestToJson(
  CarePlanRequest instance,
) => <String, dynamic>{
  'kind': _$CareKindEnumMap[instance.kind]!,
  'title': instance.title,
  'intervalValue': instance.intervalValue,
  'intervalUnit': _$IntervalUnitEnumMap[instance.intervalUnit],
  'nextDueOn': const RequiredDateOnlyConverter().toJson(instance.nextDueOn),
  'remindOffsetsDays': instance.remindOffsetsDays,
  'defaultProduct': instance.defaultProduct,
  'targets': instance.targets?.map((e) => _$VaccineTargetEnumMap[e]!).toList(),
  'presetCode': instance.presetCode,
  'notes': instance.notes,
  'active': instance.active,
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

const _$IntervalUnitEnumMap = {
  IntervalUnit.day: 'Day',
  IntervalUnit.week: 'Week',
  IntervalUnit.month: 'Month',
  IntervalUnit.year: 'Year',
  IntervalUnit.valueNull: null,
  IntervalUnit.$unknown: r'$unknown',
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
