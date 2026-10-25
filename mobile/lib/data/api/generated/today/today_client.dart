// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/today_response.dart';

part 'today_client.g.dart';

@RestApi()
abstract class TodayClient {
  factory TodayClient(Dio dio, {String? baseUrl}) = _TodayClient;

  /// Today's feedings, planned visits, care overdue or due within 30 days for all active pets, and what to buy.
  @GET('/api/v1/today')
  Future<TodayResponse> getToday({
    @Query('date') DateTime? date,
  });
}
