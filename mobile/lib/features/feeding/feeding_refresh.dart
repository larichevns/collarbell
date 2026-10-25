import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notifications_repository.dart';
import '../supplies/supply_refresh.dart';
import '../today/today_repository.dart';
import 'feeding_repository.dart';

/// Reloads everything that shows the feeding of [petId] after a change: the
/// pet's Feeding tab, Today, the list of coming reminders, the estimates of
/// supplies and, if given, one schedule.
///
/// It goes through the [container], not a widget's `ref`, so it works even
/// after the screen that made the change is gone.
void refreshFeeding(
  ProviderContainer container,
  String petId, {
  String? scheduleId,
}) {
  container.invalidate(feedingSchedulesProvider(petId));
  container.invalidate(todayProvider);
  container.invalidate(reminderLogProvider);
  // A food from supplies is used up by the feedings.
  refreshSupplyEstimates(container);
  if (scheduleId != null) {
    container.invalidate(feedingScheduleProvider(scheduleId));
  }
}
