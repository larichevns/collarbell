import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/collarbell_theme.dart';

/// Shows that files are uploading: a spinner and "Uploading 2 of 3".
class UploadProgress extends StatelessWidget {
  const UploadProgress({super.key, required this.done, required this.total});

  /// Files uploaded so far.
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final current = done < total ? done + 1 : total;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(CbSpace.s3),
        decoration: BoxDecoration(
          color: cb.sunken,
          borderRadius: BorderRadius.circular(CbRadius.md),
        ),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: CbSpace.s5,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: CbSpace.s3),
            Expanded(
              child: Text(
                done >= total
                    ? context.l10n.uploadSaving
                    : context.l10n.uploadProgress(current, total),
                style: context.cbText.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
