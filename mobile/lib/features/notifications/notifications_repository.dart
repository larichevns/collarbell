import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/app_session.dart';
import '../../data/api/generated/export.dart' as dto;
import '../../shared/error_messages.dart';
import '../me/profile_sync.dart';
import 'notifications.dart';

/// Phones registered for pushes, notification settings and the reminder
/// list. Every method throws ApiException on failure.
abstract interface class NotificationsRepository {
  /// Registers this phone for pushes under [deviceId] (chosen by the app
  /// once per installation). Called on every start and whenever Firebase
  /// changes the phone's [token].
  Future<void> registerDevice(String deviceId, String token);

  /// Stops pushes to this phone, e.g. before signing out. A phone that is
  /// not registered is no error.
  Future<void> forgetDevice(String deviceId);

  Future<NotificationSettings> getSettings();

  Future<NotificationSettings> setEnabled(
    NotificationCategory category,
    bool enabled,
  );

  Future<ReminderLog> getReminders();

  /// Sends a test push to the signed-in person's phones now.
  Future<TestPushResult> sendTest();
}

/// [NotificationsRepository] over the generated API client.
class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(this._client);

  final ApiClient _client;

  @override
  Future<void> registerDevice(String deviceId, String token) => _client.send(
    (api) => api.notifications.registerDevice(
      id: deviceId,
      // Android only for now: iPhones need Apple's key in Firebase first.
      body: dto.RegisterDeviceRequest(
        platform: dto.DevicePlatform.android,
        token: token,
        // The admin shows which versions the phones run.
        appVersion: appVersion,
      ),
    ),
  );

  @override
  Future<void> forgetDevice(String deviceId) async {
    try {
      await _client.send((api) => api.notifications.forgetDevice(id: deviceId));
    } catch (error) {
      // Gone already (or never registered): that is what was wanted.
      if (isNotFound(error)) return;
      rethrow;
    }
  }

  @override
  Future<NotificationSettings> getSettings() async => _settingsFromDto(
    await _client.send((api) => api.notifications.getNotificationSettings()),
  );

  @override
  Future<NotificationSettings> setEnabled(
    NotificationCategory category,
    bool enabled,
  ) async => _settingsFromDto(
    await _client.send(
      (api) => api.notifications.updateNotificationSettings(
        body: dto.UpdateNotificationSettingsRequest(
          categories: [
            dto.NotificationCategorySetting(
              category: _categoryToDto(category),
              enabled: enabled,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Future<ReminderLog> getReminders() async {
    final log = await _client.send((api) => api.notifications.listReminders());
    return ReminderLog(
      upcoming: [for (final entry in log.upcoming) _entryFromDto(entry)],
      recent: [for (final entry in log.recent) _entryFromDto(entry)],
    );
  }

  @override
  Future<TestPushResult> sendTest() async {
    final result = await _client.send(
      (api) => api.notifications.sendTestNotification(),
    );
    return TestPushResult(
      devices: result.devices,
      delivered: result.delivered,
      problem: switch (result.problem) {
        dto.TestPushProblem.notConfigured => TestPushProblem.notConfigured,
        dto.TestPushProblem.noDevices => TestPushProblem.noDevices,
        dto.TestPushProblem.failed ||
        dto.TestPushProblem.$unknown => TestPushProblem.failed,
        _ => null,
      },
    );
  }
}

NotificationSettings _settingsFromDto(dto.NotificationSettingsResponse s) =>
    NotificationSettings(
      pushReady: s.pushReady,
      enabled: {
        for (final setting in s.categories)
          ?_categoryFromDto(setting.category): setting.enabled,
      },
      deviceIds: [for (final device in s.devices) device.id],
    );

ReminderEntry _entryFromDto(dto.ReminderResponse r) => ReminderEntry(
  id: r.id,
  category: _categoryFromDto(r.category),
  subject: r.subject,
  fireAt: r.fireAt.toLocal(),
  status: switch (r.status) {
    dto.ReminderStatus.pending => ReminderStatus.pending,
    dto.ReminderStatus.sent => ReminderStatus.sent,
    dto.ReminderStatus.skipped => ReminderStatus.skipped,
    dto.ReminderStatus.expired => ReminderStatus.expired,
    dto.ReminderStatus.failed => ReminderStatus.failed,
    dto.ReminderStatus.$unknown => null,
  },
  reason: switch (r.reason) {
    dto.ReminderReason.notNeeded => ReminderReason.notNeeded,
    dto.ReminderReason.noRecipients => ReminderReason.noRecipients,
    dto.ReminderReason.pushNotConfigured => ReminderReason.pushNotConfigured,
    dto.ReminderReason.sendFailed => ReminderReason.sendFailed,
    _ => null,
  },
);

NotificationCategory? _categoryFromDto(dto.NotificationCategory category) =>
    switch (category) {
      dto.NotificationCategory.feeding => NotificationCategory.feeding,
      dto.NotificationCategory.care => NotificationCategory.care,
      dto.NotificationCategory.appointments =>
        NotificationCategory.appointments,
      dto.NotificationCategory.supplies => NotificationCategory.supplies,
      dto.NotificationCategory.$unknown => null,
    };

dto.NotificationCategory _categoryToDto(NotificationCategory category) =>
    switch (category) {
      NotificationCategory.feeding => dto.NotificationCategory.feeding,
      NotificationCategory.care => dto.NotificationCategory.care,
      NotificationCategory.appointments =>
        dto.NotificationCategory.appointments,
      NotificationCategory.supplies => dto.NotificationCategory.supplies,
    };

// --- Providers --------------------------------------------------------------

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => ApiNotificationsRepository(ref.watch(apiClientProvider)),
);

/// The signed-in person's notification settings.
final notificationSettingsProvider =
    FutureProvider.autoDispose<NotificationSettings>((ref) async {
      final repository = ref.watch(notificationsRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getSettings();
    });

/// The household's coming and recent reminders.
final reminderLogProvider = FutureProvider.autoDispose<ReminderLog>((
  ref,
) async {
  final repository = ref.watch(notificationsRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getReminders();
});
