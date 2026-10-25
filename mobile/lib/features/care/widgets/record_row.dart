import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/collarbell_theme.dart';
import '../care.dart';
import '../care_labels.dart';
import 'kind_icon.dart';

/// One record of the history: the kind icon, the title, and the date with
/// the product; a photo icon when the record has photos.
class RecordRow extends StatelessWidget {
  const RecordRow({super.key, required this.record, this.onTap});

  final CareRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final product = record.product;
    // The date never breaks inside; a long product name may wrap.
    final details = [keepTogether(recordDateLabel(context, record)), ?product];
    final photos = record.files.length;

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CbSpace.s4,
            vertical: CbSpace.s3,
          ),
          child: Row(
            children: [
              KindIcon(kind: record.kind),
              const SizedBox(width: CbSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: text.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      details.join(' · '),
                      style: text.bodySm.copyWith(color: cb.inkMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (photos > 0) ...[
                const SizedBox(width: CbSpace.s2),
                Icon(
                  Symbols.photo_rounded,
                  size: 18,
                  color: cb.inkMuted,
                  semanticLabel: l10n.recordPhotoCount(photos),
                ),
              ],
              if (onTap != null)
                Icon(Symbols.chevron_right_rounded, color: cb.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
