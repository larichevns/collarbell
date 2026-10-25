import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../today/today_repository.dart';
import '../weight/weight_refresh.dart';
import 'care_repository.dart';

/// Reloads everything that shows the care of [petId] after a change: the
/// Health tab, the passport sections, Today, the weight log and, if given,
/// one plan and one record.
///
/// It goes through the [container], not a widget's `ref`, so it works even
/// after the screen that made the change is gone. Screens take the
/// container before their first `await`.
void refreshCare(
  ProviderContainer container,
  String petId, {
  String? planId,
  String? recordId,
}) {
  container.invalidate(carePlansProvider(petId));
  container.invalidate(careRecordsProvider(petId));
  container.invalidate(passportRecordsProvider(petId));
  container.invalidate(todayProvider);
  // The weight a vet notes at a check-up is in the pet's weight log: a
  // record saved, deleted, made by "Done", a scan or a visit changes it.
  refreshWeight(container, petId);
  if (planId != null) container.invalidate(carePlanProvider(planId));
  if (recordId != null) container.invalidate(careRecordProvider(recordId));
}
