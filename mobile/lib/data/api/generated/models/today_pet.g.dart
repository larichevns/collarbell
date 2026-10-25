// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_pet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TodayPet _$TodayPetFromJson(Map<String, dynamic> json) => TodayPet(
  id: json['id'] as String,
  name: json['name'] as String,
  coat: Coat.fromJson(json['coat']),
  photo: json['photo'] == null
      ? null
      : FileLink.fromJson(json['photo'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TodayPetToJson(TodayPet instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'coat': _$CoatEnumMap[instance.coat]!,
  'photo': instance.photo?.toJson(),
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
