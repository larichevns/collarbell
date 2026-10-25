// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passport_contact_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PassportContactDto _$PassportContactDtoFromJson(Map<String, dynamic> json) =>
    PassportContactDto(
      name: json['name'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$PassportContactDtoToJson(PassportContactDto instance) =>
    <String, dynamic>{
      'name': instance.name,
      'address': instance.address,
      'phone': instance.phone,
      'email': instance.email,
    };
