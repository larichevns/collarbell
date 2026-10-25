// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/device_response.dart';
import '../models/notification_settings_response.dart';
import '../models/register_device_request.dart';
import '../models/reminders_response.dart';
import '../models/test_push_response.dart';
import '../models/update_notification_settings_request.dart';

part 'notifications_client.g.dart';

@RestApi()
abstract class NotificationsClient {
  factory NotificationsClient(Dio dio, {String? baseUrl}) = _NotificationsClient;

  /// Register this phone for pushes (its id is chosen by the app once); call again when its token changes.
  @PUT('/api/v1/devices/{id}')
  Future<DeviceResponse> registerDevice({
    @Path('id') required String id,
    @Body() required RegisterDeviceRequest body,
  });

  /// Stop pushes to this phone, e.g. on sign-out.
  @DELETE('/api/v1/devices/{id}')
  Future<void> forgetDevice({
    @Path('id') required String id,
  });

  /// Which kinds of reminders the signed-in person gets, and on which phones.
  @GET('/api/v1/notifications/settings')
  Future<NotificationSettingsResponse> getNotificationSettings();

  /// Turn kinds of reminders on or off.
  @PUT('/api/v1/notifications/settings')
  Future<NotificationSettingsResponse> updateNotificationSettings({
    @Body() required UpdateNotificationSettingsRequest body,
  });

  /// The household's reminders: the next 7 days, and what happened in the last 7.
  @GET('/api/v1/notifications/reminders')
  Future<RemindersResponse> listReminders();

  /// Send a test push to the signed-in person's phones now.
  @POST('/api/v1/notifications/test')
  Future<TestPushResponse> sendTestNotification();
}
