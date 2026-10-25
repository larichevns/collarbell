import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The names of the Android notification channels in the user's language.
/// The server sends every push to one of them; their ids are fixed.
@immutable
class PushChannelNames {
  const PushChannelNames({
    required this.feeding,
    required this.feedingUpdates,
    required this.care,
    required this.appointments,
    required this.supplies,
    required this.general,
  });

  final String feeding;

  /// "Who fed": someone else fed the pet, so the feeding reminder is done.
  final String feedingUpdates;
  final String care;
  final String appointments;
  final String supplies;
  final String general;
}

/// The channel of the quiet "who fed" pushes. Each replaces the feeding
/// reminder on the other phones of the household (same tag).
const feedingUpdatesChannel = 'feeding-updates';

/// The notification channels, by the ids the server sends. "Who fed" is
/// low: no sound, no pop-up, it only replaces the reminder in the list.
List<AndroidNotificationChannel> pushChannels(PushChannelNames names) => [
  AndroidNotificationChannel(
    'feeding',
    names.feeding,
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    feedingUpdatesChannel,
    names.feedingUpdates,
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  ),
  AndroidNotificationChannel('care', names.care, importance: Importance.high),
  AndroidNotificationChannel(
    'appointments',
    names.appointments,
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'supplies',
    names.supplies,
    importance: Importance.defaultImportance,
  ),
  AndroidNotificationChannel(
    'general',
    names.general,
    importance: Importance.defaultImportance,
  ),
];

/// Pushes on this phone. Firebase Cloud Messaging gives the phone's address
/// (token) and delivers pushes; Android shows them by itself while the app
/// is closed or in the background. While the app is open Android shows
/// nothing, so the app shows the push itself (flutter_local_notifications).
///
/// Android only for now: an iPhone needs Apple's key in Firebase, which
/// needs the paid Apple Developer account (spec, decisions of M4).
abstract interface class PushPlatform {
  /// Whether pushes can work on this phone at all.
  bool get supported;

  /// Creates the notification channels and starts listening for pushes.
  /// Safe to call again (e.g. when the language changes).
  Future<void> start(PushChannelNames names);

  /// Asks for permission to show notifications (Android 13+ asks once; the
  /// user can change it later in the system settings). True when allowed.
  Future<bool> requestPermission();

  /// Whether notifications are allowed now, without asking.
  Future<bool> permissionGranted();

  /// The phone's Firebase address, or null when there is none yet (no
  /// Google Play services, no network).
  Future<String?> token();

  /// New addresses Firebase gives the phone from time to time.
  Stream<String> get tokenRefreshes;

  /// The data of pushes the user tapped while the app was running.
  Stream<Map<String, String>> get taps;

  /// The data of pushes that arrived while the app is open.
  Stream<Map<String, String>> get arrivals;

  /// The data of the push that started the app, if one did.
  Future<Map<String, String>?> launchTap();

  /// Opens the system's notification settings of the app.
  Future<void> openSettings();

  /// Drops the phone's Firebase address, so pushes sent to it no longer
  /// arrive (on sign-out). The next sign-in gets a new one.
  Future<void> forgetToken();
}

/// No pushes: for builds and tests that must not touch Firebase or ask the
/// user for permission (integration tests on an Android emulator).
class DisabledPushPlatform implements PushPlatform {
  const DisabledPushPlatform();

  @override
  bool get supported => false;

  @override
  Future<void> start(PushChannelNames names) async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> permissionGranted() async => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<Map<String, String>> get taps => const Stream.empty();

  @override
  Stream<Map<String, String>> get arrivals => const Stream.empty();

  @override
  Future<Map<String, String>?> launchTap() async => null;

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> forgetToken() async {}
}

/// [PushPlatform] over firebase_messaging and flutter_local_notifications.
class FirebasePushPlatform implements PushPlatform {
  FirebasePushPlatform();

  final _local = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<Map<String, String>>.broadcast();
  final _arrivals = StreamController<Map<String, String>>.broadcast();
  var _started = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  bool get supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      Firebase.apps.isNotEmpty;

  @override
  Future<void> start(PushChannelNames names) async {
    if (!supported) return;
    if (!_started) {
      _started = true;
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final data = _decode(response.payload);
          if (data != null) _taps.add(data);
        },
      );
      FirebaseMessaging.onMessage.listen(_showWhileOpen);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _taps.add(_data(message)),
      );
    }
    // Channels are created (or renamed) every time: their names follow the
    // app's language. The server picks the channel of each push.
    final android = _android;
    for (final channel in pushChannels(names)) {
      await android?.createNotificationChannel(channel);
    }
  }

  /// Shows a push that arrived while the app is open, as Android would have
  /// shown it: same channel, and the same tag, so a newer push about the
  /// same thing replaces it. A "who fed" push replaces the reminder quietly
  /// (on Android 7 the channel's importance isn't used, so it says it too).
  Future<void> _showWhileOpen(RemoteMessage message) async {
    _arrivals.add(_data(message));
    final notification = message.notification;
    if (notification == null) return;
    final android = notification.android;
    final channel = android?.channelId ?? 'general';
    final quiet = channel == feedingUpdatesChannel;
    await _local.show(
      // Firebase shows its notifications with id 0; tags tell them apart.
      id: 0,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel,
          tag: android?.tag,
          icon: 'ic_notification',
          importance: quiet ? Importance.low : Importance.defaultImportance,
          priority: quiet ? Priority.low : Priority.defaultPriority,
          silent: quiet,
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
        ),
      ),
      payload: jsonEncode(_data(message)),
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  @override
  Future<bool> permissionGranted() async {
    if (!supported) return false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<String?> token() async =>
      supported ? FirebaseMessaging.instance.getToken() : null;

  @override
  Stream<String> get tokenRefreshes => supported
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream.empty();

  @override
  Stream<Map<String, String>> get taps => _taps.stream;

  @override
  Stream<Map<String, String>> get arrivals => _arrivals.stream;

  @override
  Future<Map<String, String>?> launchTap() async {
    if (!supported) return null;
    // Started by tapping a push Android showed (app was closed)...
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) return _data(message);
    // ...or one the app showed itself while it was open.
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      return _decode(launch?.notificationResponse?.payload);
    }
    return null;
  }

  @override
  Future<void> openSettings() async => _android?.openAppNotificationSettings();

  @override
  Future<void> forgetToken() async {
    if (supported) await FirebaseMessaging.instance.deleteToken();
  }

  static Map<String, String> _data(RemoteMessage message) => {
    for (final entry in message.data.entries) entry.key: '${entry.value}',
  };

  static Map<String, String>? _decode(String? payload) {
    if (payload == null) return null;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map
          ? {
              for (final entry in decoded.entries)
                '${entry.key}': '${entry.value}',
            }
          : null;
    } on FormatException {
      return null;
    }
  }
}

/// The phone's push platform. Tests replace it with a fake.
final pushPlatformProvider = Provider<PushPlatform>(
  (ref) => FirebasePushPlatform(),
);
