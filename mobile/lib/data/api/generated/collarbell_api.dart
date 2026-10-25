// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'me/me_client.dart';
import 'households/households_client.dart';
import 'pets/pets_client.dart';
import 'weight/weight_client.dart';
import 'passport/passport_client.dart';
import 'files/files_client.dart';
import 'documents/documents_client.dart';
import 'care/care_client.dart';
import 'today/today_client.dart';
import 'ai/ai_client.dart';
import 'supplies/supplies_client.dart';
import 'events/events_client.dart';
import 'plan/plan_client.dart';
import 'live/live_client.dart';
import 'feeding/feeding_client.dart';
import 'appointments/appointments_client.dart';
import 'notifications/notifications_client.dart';

/// Collarbell.Api | v1 `v1.0.0`
class CollarbellApi {
  CollarbellApi(
    Dio dio, {
    String? baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1.0.0';

  MeClient? _me;
  HouseholdsClient? _households;
  PetsClient? _pets;
  WeightClient? _weight;
  PassportClient? _passport;
  FilesClient? _files;
  DocumentsClient? _documents;
  CareClient? _care;
  TodayClient? _today;
  AiClient? _ai;
  SuppliesClient? _supplies;
  EventsClient? _events;
  PlanClient? _plan;
  LiveClient? _live;
  FeedingClient? _feeding;
  AppointmentsClient? _appointments;
  NotificationsClient? _notifications;

  MeClient get me => _me ??= MeClient(_dio, baseUrl: _baseUrl);

  HouseholdsClient get households => _households ??= HouseholdsClient(_dio, baseUrl: _baseUrl);

  PetsClient get pets => _pets ??= PetsClient(_dio, baseUrl: _baseUrl);

  WeightClient get weight => _weight ??= WeightClient(_dio, baseUrl: _baseUrl);

  PassportClient get passport => _passport ??= PassportClient(_dio, baseUrl: _baseUrl);

  FilesClient get files => _files ??= FilesClient(_dio, baseUrl: _baseUrl);

  DocumentsClient get documents => _documents ??= DocumentsClient(_dio, baseUrl: _baseUrl);

  CareClient get care => _care ??= CareClient(_dio, baseUrl: _baseUrl);

  TodayClient get today => _today ??= TodayClient(_dio, baseUrl: _baseUrl);

  AiClient get ai => _ai ??= AiClient(_dio, baseUrl: _baseUrl);

  SuppliesClient get supplies => _supplies ??= SuppliesClient(_dio, baseUrl: _baseUrl);

  EventsClient get events => _events ??= EventsClient(_dio, baseUrl: _baseUrl);

  PlanClient get plan => _plan ??= PlanClient(_dio, baseUrl: _baseUrl);

  LiveClient get live => _live ??= LiveClient(_dio, baseUrl: _baseUrl);

  FeedingClient get feeding => _feeding ??= FeedingClient(_dio, baseUrl: _baseUrl);

  AppointmentsClient get appointments => _appointments ??= AppointmentsClient(_dio, baseUrl: _baseUrl);

  NotificationsClient get notifications => _notifications ??= NotificationsClient(_dio, baseUrl: _baseUrl);
}
