import 'package:flutter/foundation.dart';

/// Kinds of reminders a person can turn off; on Android each is also a
/// notification channel with its own sound settings.
enum NotificationCategory { feeding, care, appointments, supplies }

/// The person's notification settings as the server keeps them.
@immutable
class NotificationSettings {
  const NotificationSettings({
    required this.pushReady,
    required this.enabled,
    required this.deviceIds,
  });

  /// False when the server can't send pushes (it has no Firebase key).
  final bool pushReady;

  /// Whether each kind of reminder is on. A kind this app doesn't know is
  /// left out.
  final Map<NotificationCategory, bool> enabled;

  /// The person's phones registered for pushes (this one among them, when
  /// registering worked).
  final List<String> deviceIds;

  bool isEnabled(NotificationCategory category) => enabled[category] ?? true;
}

/// What happened to a reminder.
enum ReminderStatus { pending, sent, skipped, expired, failed }

/// Why a reminder was skipped or failed.
enum ReminderReason { notNeeded, noRecipients, pushNotConfigured, sendFailed }

/// A reminder of the household: coming, or sent (or not) lately.
@immutable
class ReminderEntry {
  const ReminderEntry({
    required this.id,
    required this.category,
    required this.subject,
    required this.fireAt,
    required this.status,
    this.reason,
  });

  final String id;

  /// Null for a kind this app doesn't know.
  final NotificationCategory? category;

  /// What it is about in the user's own words, e.g. "Murka: Rabies".
  final String subject;

  /// When it is (or was) meant to arrive, local time.
  final DateTime fireAt;

  /// Null for a status this app doesn't know.
  final ReminderStatus? status;
  final ReminderReason? reason;
}

/// The coming reminders (next 7 days, soonest first) and the recent ones
/// (last 7 days, newest first).
@immutable
class ReminderLog {
  const ReminderLog({required this.upcoming, required this.recent});

  final List<ReminderEntry> upcoming;
  final List<ReminderEntry> recent;
}

/// Why the test push reached no phone.
enum TestPushProblem { notConfigured, noDevices, failed }

@immutable
class TestPushResult {
  const TestPushResult({
    required this.devices,
    required this.delivered,
    this.problem,
  });

  final int devices;
  final int delivered;
  final TestPushProblem? problem;
}
