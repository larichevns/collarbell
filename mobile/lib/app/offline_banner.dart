import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/api/api_providers.dart';
import '../l10n/l10n.dart';
import '../theme/collarbell_theme.dart';

/// A strip above the bottom navigation while the server can't be reached
/// (the Mac asleep, the phone away from home). The screens then show the
/// copies saved on the phone, and the strip says how old the oldest one is.
///
/// While it shows, it asks the server every 20 seconds and whenever the app
/// comes back to the screen; once the server answers, every screen reloads
/// with live data and the strip goes away. Changes wait for that.
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  static const checkEvery = Duration(seconds: 20);

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  var _checking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!_reachable) unawaited(_check());
        _schedule();
      },
      onHide: _stop,
    );
    ref.listenManual(serverReachabilityProvider, (_, _) => _schedule());
    _schedule();
  }

  @override
  void dispose() {
    _stop();
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _reachable => ref.read(serverReachabilityProvider).reachable;

  /// Asks the server periodically while it doesn't answer, and stops once
  /// it does.
  void _schedule() {
    if (_reachable) {
      _stop();
    } else {
      _timer ??= Timer.periodic(OfflineBanner.checkEvery, (_) => _check());
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await ref.read(apiClientProvider).checkServer();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(serverReachabilityProvider);
    if (status.reachable) return const SizedBox.shrink();
    final l10n = context.l10n;
    final c = context.cb;
    final dataAt = status.dataAt;
    final message = dataAt == null
        ? l10n.offlineBanner
        : l10n.offlineBannerSince(_when(context, dataAt));
    return Semantics(
      liveRegion: true,
      child: ColoredBox(
        color: c.inverseSurface,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: CbSpace.s4,
            end: CbSpace.s2,
          ),
          child: Row(
            children: [
              Icon(Symbols.cloud_off_rounded, size: 20, color: c.onInverse),
              const SizedBox(width: CbSpace.s3),
              Expanded(
                child: Text(
                  message,
                  style: context.cbText.bodySm.copyWith(color: c.onInverse),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: c.onInverse),
                onPressed: _checking ? null : _check,
                child: _checking
                    ? SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.onInverse,
                        ),
                      )
                    : Text(l10n.commonTryAgain),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "14:05" for today, "1 Oct, 14:05" for another day.
  static String _when(BuildContext context, DateTime at) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = DateFormat.Hm(locale).format(at);
    final now = DateTime.now();
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return today ? time : '${DateFormat.MMMd(locale).format(at)}, $time';
  }
}
