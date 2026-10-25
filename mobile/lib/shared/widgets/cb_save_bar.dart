import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/collarbell_theme.dart';
import 'cb_notice.dart';

/// The "Save" button pinned under a form (the screen's one filled button),
/// so it stays in reach however long the form is. While [busy], it shows a
/// spinner and, if given, [busyLabel] ("Uploading 1 of 3").
///
/// [error] appears above the button, where the user looks after tapping
/// it, e.g. "Check the highlighted fields" or "Can't reach the server".
class CbSaveBar extends StatelessWidget {
  const CbSaveBar({
    super.key,
    required this.busy,
    required this.onSave,
    this.busyLabel,
    this.error,
    this.label,
    this.secondary,
  });

  final bool busy;

  /// Null turns the button off, e.g. when there is nothing to save.
  final VoidCallback? onSave;
  final String? busyLabel;
  final String? error;

  /// The button's words; "Save" by default.
  final String? label;

  /// A quieter action under the button, e.g. "Discard scan".
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final busyLabel = this.busyLabel;
    final error = this.error;
    final secondary = this.secondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.cb.surface,
        border: Border(top: BorderSide(color: context.cb.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(CbSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                CbNotice.error(message: error),
                const SizedBox(height: CbSpace.s3),
              ],
              FilledButton(
                onPressed: busy ? null : onSave,
                child: busy
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox.square(
                            dimension: CbSpace.s5,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          if (busyLabel != null) ...[
                            const SizedBox(width: CbSpace.s2),
                            Flexible(
                              child: Text(
                                busyLabel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      )
                    : Text(label ?? context.l10n.commonSave),
              ),
              if (secondary != null) ...[
                // 12 between the buttons as seen: 8 here plus 2 + 2 of
                // their touch areas (48 around a 44-high button).
                const SizedBox(height: CbSpace.s2),
                secondary,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
