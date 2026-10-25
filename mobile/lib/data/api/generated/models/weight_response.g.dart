// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weight_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeightResponse _$WeightResponseFromJson(Map<String, dynamic> json) =>
    WeightResponse(
      id: json['id'] as String,
      petId: json['petId'] as String,
      source: WeightSource.fromJson(json['source']),
      measuredOn: const RequiredDateOnlyConverter().fromJson(
        json['measuredOn'] as String,
      ),
      weightKg: (json['weightKg'] as num).toDouble(),
      bcs: (json['bcs'] as num?)?.toInt(),
      bcsScale: (json['bcsScale'] as num?)?.toInt(),
      note: json['note'] as String?,
      createdAt: const RequiredDateOnlyConverter().fromJson(
        json['createdAt'] as String,
      ),
      updatedAt: const RequiredDateOnlyConverter().fromJson(
        json['updatedAt'] as String,
      ),
    );

Map<String, dynamic> _$WeightResponseToJson(
  WeightResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'petId': instance.petId,
  'source': _$WeightSourceEnumMap[instance.source]!,
  'measuredOn': const RequiredDateOnlyConverter().toJson(instance.measuredOn),
  'weightKg': instance.weightKg,
  'bcs': instance.bcs,
  'bcsScale': instance.bcsScale,
  'note': instance.note,
  'createdAt': const RequiredDateOnlyConverter().toJson(instance.createdAt),
  'updatedAt': const RequiredDateOnlyConverter().toJson(instance.updatedAt),
};

const _$WeightSourceEnumMap = {
  WeightSource.weighing: 'Weighing',
  WeightSource.careRecord: 'CareRecord',
  WeightSource.$unknown: r'$unknown',
};
