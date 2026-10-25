import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai_repository.dart';

/// Asks the server again whether it has AI when that couldn't be loaded,
/// as soon as the user is back at [child]: the app returns from the
/// background, or the screen is shown again (another tab or screen was on
/// top, or the screen opens anew). A status that loaded stays as it is.
///
/// Without it, a status that failed once (no connection at start) would
/// stay failed: the scan buttons would stay hidden and More would say
/// "Couldn't check" until the app restarts.
class AiStatusRefresher extends ConsumerStatefulWidget {
  const AiStatusRefresher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AiStatusRefresher> createState() => _AiStatusRefresherState();
}

class _AiStatusRefresherState extends ConsumerState<AiStatusRefresher> {
  late final AppLifecycleListener _lifecycle;

  /// Whether this part of the screen is shown: false while another tab or
  /// screen covers it.
  ValueListenable<bool>? _shown;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _retryIfFailed);
    _retrySoon();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = TickerMode.getNotifier(context);
    if (shown != _shown) {
      _shown?.removeListener(_onShownChanged);
      _shown = shown..addListener(_onShownChanged);
    }
  }

  @override
  void dispose() {
    _shown?.removeListener(_onShownChanged);
    _lifecycle.dispose();
    super.dispose();
  }

  void _onShownChanged() {
    if (_shown?.value ?? false) _retrySoon();
  }

  /// After the frame: the change that shows the screen comes while the
  /// screen builds, and providers can't change then.
  void _retrySoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _retryIfFailed();
    });
  }

  void _retryIfFailed() {
    final status = ref.read(aiStatusProvider);
    if (status.hasError && !status.isLoading) ref.invalidate(aiStatusProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
