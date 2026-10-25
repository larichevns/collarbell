// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/live_ticket_response.dart';

part 'live_client.g.dart';

@RestApi()
abstract class LiveClient {
  factory LiveClient(Dio dio, {String? baseUrl}) = _LiveClient;

  /// A one-time ticket to open the live updates' hub from a browser: /hubs/household?access_token=<ticket>&household=<id>. Good once, for a minute; 429 with ten unused.
  @POST('/api/v1/live/tickets')
  Future<LiveTicketResponse> issueLiveTicket();
}
