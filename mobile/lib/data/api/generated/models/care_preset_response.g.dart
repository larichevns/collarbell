// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'care_preset_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CarePresetResponse _$CarePresetResponseFromJson(Map<String, dynamic> json) =>
    CarePresetResponse(
      code: json['code'] as String,
      species: json['species'] == null
          ? null
          : Species.fromJson(json['species']),
      kind: CareKind.fromJson(json['kind']),
      title: json['title'] as String,
      intervalValue: (json['intervalValue'] as num?)?.toInt(),
      intervalUnit: json['intervalUnit'] == null
          ? null
          : IntervalUnit.fromJson(json['intervalUnit']),
      targets: (json['targets'] as List<dynamic>)
          .map(VaccineTarget.fromJson)
          .toList(),
      dogOnly: json['dogOnly'] as bool,
      note: json['note'] as String?,
    );

Map<String, dynamic> _$CarePresetResponseToJson(
  CarePresetResponse instance,
) => <String, dynamic>{
  'code': instance.code,
  'species': _$SpeciesEnumMap[instance.species],
  'kind': _$CareKindEnumMap[instance.kind]!,
  'title': instance.title,
  'intervalValue': instance.intervalValue,
  'intervalUnit': _$IntervalUnitEnumMap[instance.intervalUnit],
  'targets': instance.targets.map((e) => _$VaccineTargetEnumMap[e]!).toList(),
  'dogOnly': instance.dogOnly,
  'note': instance.note,
};

const _$SpeciesEnumMap = {
  Species.cat: 'Cat',
  Species.dog: 'Dog',
  Species.other: 'Other',
  Species.$unknown: r'$unknown',
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
