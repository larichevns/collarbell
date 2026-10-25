// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'existing_supply.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExistingSupply _$ExistingSupplyFromJson(Map<String, dynamic> json) =>
    ExistingSupply(
      id: json['id'] as String,
      name: json['name'] as String,
      active: json['active'] as bool,
    );

Map<String, dynamic> _$ExistingSupplyToJson(ExistingSupply instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'active': instance.active,
    };
