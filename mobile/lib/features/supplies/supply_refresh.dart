import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feeding/feeding_repository.dart';
import '../notifications/notifications_repository.dart';
import '../today/today_repository.dart';
import 'supplies_repository.dart';

/// Reloads everything that shows supplies after a change: the list, Today
/// ("to buy"), the coming reminders, one item and its history when given,
/// and the feeding schedules (they show the food's name, which follows the
/// item's).
///
/// It goes through the [container], not a widget's `ref`, so it works even
/// after the screen that made the change is gone.
void refreshSupplies(ProviderContainer container, {String? supplyId}) {
  container.invalidate(suppliesProvider);
  container.invalidate(todayProvider);
  container.invalidate(reminderLogProvider);
  container.invalidate(feedingSchedulesProvider);
  if (supplyId != null) {
    container.invalidate(supplyProvider(supplyId));
    container.invalidate(stockProvider(supplyId));
  }
}

/// Reloads the estimates after a change elsewhere that changes the daily use
/// of food: a feeding saved, paused or deleted, a pet archived or deleted.
void refreshSupplyEstimates(ProviderContainer container) {
  container.invalidate(suppliesProvider);
  container.invalidate(supplyProvider);
}
