// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_push_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TestPushResponse _$TestPushResponseFromJson(Map<String, dynamic> json) =>
    TestPushResponse(
      devices: (json['devices'] as num).toInt(),
      delivered: (json['delivered'] as num).toInt(),
      problem: json['problem'] == null
          ? null
          : TestPushProblem.fromJson(json['problem']),
    );

Map<String, dynamic> _$TestPushResponseToJson(TestPushResponse instance) =>
    <String, dynamic>{
      'devices': instance.devices,
      'delivered': instance.delivered,
      'problem': _$TestPushProblemEnumMap[instance.problem],
    };

const _$TestPushProblemEnumMap = {
  TestPushProblem.notConfigured: 'NotConfigured',
  TestPushProblem.noDevices: 'NoDevices',
  TestPushProblem.failed: 'Failed',
  TestPushProblem.valueNull: null,
  TestPushProblem.$unknown: r'$unknown',
};
