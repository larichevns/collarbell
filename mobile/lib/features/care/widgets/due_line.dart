import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/cb_status_tag.dart';
import '../../../theme/collarbell_theme.dart';
import '../care.dart';
import '../care_labels.dart';

/// When something is due. Overdue and due soon are status tags (red and
/// yellow) with the date after them; the rest is calm, muted text with an
/// icon. Colour is never alone: the icon and the words say the same, e.g.
/// "3 days overdue · Sep 28, 2026".
class DueLine extends StatelessWidget {
  const DueLine({
    super.key,
    required this.status,
    required this.daysLeft,
    required this.dueOn,
  });

  final CareStatus status;
  final int daysLeft;
  final DateTime dueOn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final style = context.cbText.bodySm.copyWith(color: cb.inkMuted);
    final label = dueLabel(l10n, daysLeft);
    // The date never breaks inside.
    final date = keepTogether(l10n.dateMedium(dueOn));
    final tag = switch (status) {
      CareStatus.overdue => CbStatusTag.overdue(label),
      CareStatus.dueSoon => CbStatusTag.soon(label),
      _ => null,
    };
    if (tag != null) {
      return MergeSemantics(
        child: Wrap(
          spacing: CbSpace.s2,
          runSpacing: CbSpace.s1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            tag,
            Text(date, style: style),
          ],
        ),
      );
    }
    final icon = status == CareStatus.inactive
        ? Symbols.pause_circle_rounded
        : Symbols.event_rounded;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Centres the icon on the first line of text.
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: cb.inkMuted),
        ),
        const SizedBox(width: CbSpace.s1),
        Expanded(child: Text('$label · $date', style: style)),
      ],
    );
  }
}
