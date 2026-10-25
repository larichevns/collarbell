// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'existing_supply.g.dart';

@JsonSerializable()
class ExistingSupply {
  const ExistingSupply({
    required this.id,
    required this.name,
    required this.active,
  });
  
  factory ExistingSupply.fromJson(Map<String, Object?> json) => _$ExistingSupplyFromJson(json);
  
  final String id;
  final String name;
  final bool active;

  Map<String, Object?> toJson() => _$ExistingSupplyToJson(this);
}
