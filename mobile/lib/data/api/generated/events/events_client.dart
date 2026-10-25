// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/app_events_request.dart';

part 'events_client.g.dart';

@RestApi()
abstract class EventsClient {
  factory EventsClient(Dio dio, {String? baseUrl}) = _EventsClient;

  /// What the app did and saw (screens, actions, errors), up to 50 at a time; kept for a week for support.
  @POST('/api/v1/events')
  Future<void> reportAppEvents({
    @Body() required AppEventsRequest body,
  });
}
