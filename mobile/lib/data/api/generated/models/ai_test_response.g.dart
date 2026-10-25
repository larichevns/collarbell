// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_test_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiTestResponse _$AiTestResponseFromJson(Map<String, dynamic> json) =>
    AiTestResponse(
      ok: json['ok'] as bool,
      model: json['model'] as String?,
      latencyMs: (json['latencyMs'] as num).toInt(),
      problem: json['problem'] == null
          ? null
          : AiTestProblem.fromJson(json['problem']),
    );

Map<String, dynamic> _$AiTestResponseToJson(AiTestResponse instance) =>
    <String, dynamic>{
      'ok': instance.ok,
      'model': instance.model,
      'latencyMs': instance.latencyMs,
      'problem': _$AiTestProblemEnumMap[instance.problem],
    };

const _$AiTestProblemEnumMap = {
  AiTestProblem.notConfigured: 'NotConfigured',
  AiTestProblem.busy: 'Busy',
  AiTestProblem.rejected: 'Rejected',
  AiTestProblem.wrongAnswer: 'WrongAnswer',
  AiTestProblem.valueNull: null,
  AiTestProblem.$unknown: r'$unknown',
};
