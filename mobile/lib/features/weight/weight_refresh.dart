import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'weight_repository.dart';

/// Reloads everything that shows the weight of [petId] after a change: its
/// weight log, which the Weight tab and the Overview show.
///
/// It goes through the [container], not a widget's `ref`, so it works even
/// after the sheet that made the change is gone. A care record can note a
/// weight too, so `refreshCare` calls it as well.
void refreshWeight(ProviderContainer container, String petId) {
  container.invalidate(weightLogProvider(petId));
}
