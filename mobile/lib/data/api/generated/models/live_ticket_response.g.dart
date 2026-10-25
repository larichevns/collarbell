// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_ticket_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiveTicketResponse _$LiveTicketResponseFromJson(Map<String, dynamic> json) =>
    LiveTicketResponse(
      ticket: json['ticket'] as String,
      expiresAt: const RequiredDateOnlyConverter().fromJson(
        json['expiresAt'] as String,
      ),
    );

Map<String, dynamic> _$LiveTicketResponseToJson(LiveTicketResponse instance) =>
    <String, dynamic>{
      'ticket': instance.ticket,
      'expiresAt': const RequiredDateOnlyConverter().toJson(instance.expiresAt),
    };
