// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'package:collarbell/data/api/date_only_converter.dart';
part 'live_ticket_response.g.dart';

@JsonSerializable()
class LiveTicketResponse {
  const LiveTicketResponse({
    required this.ticket,
    required this.expiresAt,
  });
  
  factory LiveTicketResponse.fromJson(Map<String, Object?> json) => _$LiveTicketResponseFromJson(json);
  
  final String ticket;
	@RequiredDateOnlyConverter()
  final DateTime expiresAt;

  Map<String, Object?> toJson() => _$LiveTicketResponseToJson(this);
}
