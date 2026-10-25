import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/push_registration.dart';
import 'today_repository.dart';

/// For the screens that show Today's data (Today, and Home with its next
/// feeding and what is due): they read it again when the app comes back to
/// the screen and after midnight. Whichever of them is built does it; the
/// first tab the app opens on is Home, and Today may not be built yet.
mixin TodayReload<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    // Back in the app after a while: the day may have changed, and another
    // phone may have marked a feeding meanwhile.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(todayProvider);
        // Back from the system settings, maybe with notifications allowed.
        final push = ref.read(pushRegistrationProvider).value;
        if (push == PushState.denied || push == PushState.notAsked) {
          ref.invalidate(pushRegistrationProvider);
        }
      },
    );
    _reloadAfterMidnight();
  }

  /// A new day starts while the screen is open: yesterday's feedings must
  /// not be marked as today's.
  void _reloadAfterMidnight() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 1);
    _midnight = Timer(next.difference(now), () {
      ref.invalidate(todayProvider);
      _reloadAfterMidnight();
    });
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }
}
