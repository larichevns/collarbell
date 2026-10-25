// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_routine_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompleteRoutineRequest _$CompleteRoutineRequestFromJson(
  Map<String, dynamic> json,
) => CompleteRoutineRequest(
  date: const RequiredDateOnlyConverter().fromJson(json['date'] as String),
  time: json['time'] as String,
  status: json['status'] == null
      ? null
      : CompletionStatus.fromJson(json['status']),
);

Map<String, dynamic> _$CompleteRoutineRequestToJson(
  CompleteRoutineRequest instance,
) => <String, dynamic>{
  'date': const RequiredDateOnlyConverter().toJson(instance.date),
  'time': instance.time,
  'status': _$CompletionStatusEnumMap[instance.status],
};

const _$CompletionStatusEnumMap = {
  CompletionStatus.done: 'Done',
  CompletionStatus.skipped: 'Skipped',
  CompletionStatus.$unknown: r'$unknown',
};
