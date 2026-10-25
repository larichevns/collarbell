import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/collarbell_theme.dart';

/// A note the user wrote or dictated, quoted as they wrote it, where a scan
/// shows its photos: while AI reads it, when it failed, and on the review,
/// to check the draft against it. Like the words an entry was read from
/// ([DraftEvidence]), on a grey box. With [writtenAt], when it was written
/// ("Written Oct 6, 2026, 14:05"): what its "yesterday" means.
class NoteQuote extends StatelessWidget {
  const NoteQuote({super.key, required this.text, this.writtenAt});

  final String text;

  /// A moment, shown in local time.
  final DateTime? writtenAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final writtenAt = this.writtenAt?.toLocal();
    return Container(
      padding: const EdgeInsets.all(CbSpace.s3),
      decoration: BoxDecoration(
        color: cb.sunken,
        borderRadius: BorderRadius.circular(CbRadius.md),
      ),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (writtenAt != null) ...[
              Text(
                l10n.noteWrittenAt(
                  l10n.dateWithTime(
                    writtenAt,
                    TimeOfDay.fromDateTime(writtenAt).format(context),
                  ),
                ),
                style: text.caption.copyWith(color: cb.inkMuted),
              ),
              const SizedBox(height: CbSpace.s1),
            ],
            Text(
              l10n.scanEvidence(this.text),
              style: text.body.copyWith(color: cb.ink),
            ),
          ],
        ),
      ),
    );
  }
}
