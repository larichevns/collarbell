// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlanResponse _$PlanResponseFromJson(Map<String, dynamic> json) => PlanResponse(
  plan: PlanKind.fromJson(json['plan']),
  source: json['source'] == null ? null : PlanSource.fromJson(json['source']),
  expiresAt: const DateOnlyConverter().fromJson(json['expiresAt'] as String?),
  aiPhotosPerMonth: (json['aiPhotosPerMonth'] as num).toInt(),
  aiPhotosUsed: (json['aiPhotosUsed'] as num).toInt(),
  resetsAt: const RequiredDateOnlyConverter().fromJson(
    json['resetsAt'] as String,
  ),
  premiumAiPhotosPerMonth: (json['premiumAiPhotosPerMonth'] as num).toInt(),
);

Map<String, dynamic> _$PlanResponseToJson(PlanResponse instance) =>
    <String, dynamic>{
      'plan': _$PlanKindEnumMap[instance.plan]!,
      'source': _$PlanSourceEnumMap[instance.source],
      'expiresAt': const DateOnlyConverter().toJson(instance.expiresAt),
      'aiPhotosPerMonth': instance.aiPhotosPerMonth,
      'aiPhotosUsed': instance.aiPhotosUsed,
      'resetsAt': const RequiredDateOnlyConverter().toJson(instance.resetsAt),
      'premiumAiPhotosPerMonth': instance.premiumAiPhotosPerMonth,
    };

const _$PlanKindEnumMap = {
  PlanKind.free: 'Free',
  PlanKind.premium: 'Premium',
  PlanKind.$unknown: r'$unknown',
};

const _$PlanSourceEnumMap = {
  PlanSource.manual: 'Manual',
  PlanSource.paddle: 'Paddle',
  PlanSource.appStore: 'AppStore',
  PlanSource.valueNull: null,
  PlanSource.$unknown: r'$unknown',
};
