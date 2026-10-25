// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_completion_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoutineCompletionResponse _$RoutineCompletionResponseFromJson(
  Map<String, dynamic> json,
) => RoutineCompletionResponse(
  id: json['id'] as String,
  routineId: json['routineId'] as String,
  date: const RequiredDateOnlyConverter().fromJson(json['date'] as String),
  time: json['time'] as String,
  status: CompletionStatus.fromJson(json['status']),
  doneAt: const RequiredDateOnlyConverter().fromJson(json['doneAt'] as String),
  byName: json['byName'] as String?,
  byMe: json['byMe'] as bool,
);

Map<String, dynamic> _$RoutineCompletionResponseToJson(
  RoutineCompletionResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'routineId': instance.routineId,
  'date': const RequiredDateOnlyConverter().toJson(instance.date),
  'time': instance.time,
  'status': _$CompletionStatusEnumMap[instance.status]!,
  'doneAt': const RequiredDateOnlyConverter().toJson(instance.doneAt),
  'byName': instance.byName,
  'byMe': instance.byMe,
};

const _$CompletionStatusEnumMap = {
  CompletionStatus.done: 'Done',
  CompletionStatus.skipped: 'Skipped',
  CompletionStatus.$unknown: r'$unknown',
};
