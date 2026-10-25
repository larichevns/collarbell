import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../care/care_refresh.dart';
import '../notifications/notifications_repository.dart';
import '../today/today_repository.dart';
import 'visits_repository.dart';

/// Reloads everything that shows visits after a change: the list, Today,
/// the coming reminders, one visit when given, and the care of [petIds]
/// (a visit that took place adds records and moves plans).
///
/// It goes through the [container], not a widget's `ref`, so it works even
/// after the screen that made the change is gone.
void refreshVisits(
  ProviderContainer container, {
  String? visitId,
  Iterable<String> petIds = const [],
}) {
  container.invalidate(visitsProvider);
  container.invalidate(todayProvider);
  container.invalidate(reminderLogProvider);
  if (visitId != null) container.invalidate(visitProvider(visitId));
  for (final petId in petIds) {
    refreshCare(container, petId);
  }
}
