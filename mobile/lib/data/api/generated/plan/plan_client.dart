// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/plan_response.dart';

part 'plan_client.g.dart';

@RestApi()
abstract class PlanClient {
  factory PlanClient(Dio dio, {String? baseUrl}) = _PlanClient;

  /// The household's plan (Free or Premium), this month's AI photos and the limit. Premium is given by hand for now; there are no payments yet.
  @GET('/api/v1/plan')
  Future<PlanResponse> getPlan();
}
