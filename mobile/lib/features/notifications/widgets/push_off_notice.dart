import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/cb_notice.dart';
import '../../../theme/collarbell_theme.dart';
import '../push_platform.dart';
import '../push_registration.dart';

/// After the user refused notifications: reminders won't come. Shown on
/// Today and in the feeding form, with the way to the system settings; it
/// goes away once notifications are allowed (Today checks again when the
/// app comes back).
class PushOffNotice extends ConsumerWidget {
  const PushOffNotice({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(pushRegistrationProvider).value != PushState.denied) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CbNotice.warning(message: l10n.pushOffNotice),
          const SizedBox(height: CbSpace.s2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              key: const ValueKey('openPushSettings'),
              onPressed: () => ref.read(pushPlatformProvider).openSettings(),
              icon: const Icon(Symbols.settings_rounded),
              label: Text(l10n.notificationsOpenSettings),
            ),
          ),
        ],
      ),
    );
  }
}
