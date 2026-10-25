// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_care_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TodayCareItem _$TodayCareItemFromJson(Map<String, dynamic> json) =>
    TodayCareItem(
      planId: json['planId'] as String,
      petId: json['petId'] as String,
      petName: json['petName'] as String,
      petCoat: Coat.fromJson(json['petCoat']),
      petPhoto: json['petPhoto'] == null
          ? null
          : FileLink.fromJson(json['petPhoto'] as Map<String, dynamic>),
      kind: CareKind.fromJson(json['kind']),
      title: json['title'] as String,
      nextDueOn: const RequiredDateOnlyConverter().fromJson(
        json['nextDueOn'] as String,
      ),
      status: CareStatus.fromJson(json['status']),
      daysLeft: (json['daysLeft'] as num).toInt(),
    );

Map<String, dynamic> _$TodayCareItemToJson(TodayCareItem instance) =>
    <String, dynamic>{
      'planId': instance.planId,
      'petId': instance.petId,
      'petName': instance.petName,
      'petCoat': _$CoatEnumMap[instance.petCoat]!,
      'petPhoto': instance.petPhoto?.toJson(),
      'kind': _$CareKindEnumMap[instance.kind]!,
      'title': instance.title,
      'nextDueOn': const RequiredDateOnlyConverter().toJson(instance.nextDueOn),
      'status': _$CareStatusEnumMap[instance.status]!,
      'daysLeft': instance.daysLeft,
    };

const _$CoatEnumMap = {
  Coat.smoke: 'Smoke',
  Coat.ginger: 'Ginger',
  Coat.fawn: 'Fawn',
  Coat.cocoa: 'Cocoa',
  Coat.lilac: 'Lilac',
  Coat.ink: 'Ink',
  Coat.$unknown: r'$unknown',
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

const _$CareStatusEnumMap = {
  CareStatus.overdue: 'Overdue',
  CareStatus.dueSoon: 'DueSoon',
  CareStatus.upcoming: 'Upcoming',
  CareStatus.inactive: 'Inactive',
  CareStatus.$unknown: r'$unknown',
};
