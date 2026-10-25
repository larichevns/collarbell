import 'package:flutter/material.dart';

import '../../theme/collarbell_theme.dart';

/// How pressing a status is.
enum CbStatusTone {
  /// Soon, time to buy, check this: `accent` (yellow) fill, `on-accent`
  /// text.
  soon,

  /// Overdue, ran out: `danger` (red) fill, `on-danger` text.
  overdue,
}

/// A status in a coloured tag with an icon: "Due soon", "Time to buy",
/// "3 days overdue".
///
/// Yellow text on white can't be read, so "soon" and "check this" are never
/// coloured text: they are this tag, and so is "overdue", to match. Calm
/// states stay plain `ink-muted` text. A short label makes a pill; a long
/// message wraps inside the tag, which keeps its rounded corners.
class CbStatusTag extends StatelessWidget {
  const CbStatusTag({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  /// "Soon": yellow, a clock by default.
  const CbStatusTag.soon(
    this.label, {
    super.key,
    this.icon = Symbols.schedule_rounded,
  }) : tone = CbStatusTone.soon;

  /// "Overdue": red, an exclamation mark by default.
  const CbStatusTag.overdue(
    this.label, {
    super.key,
    this.icon = Symbols.error_rounded,
  }) : tone = CbStatusTone.overdue;

  final String label;
  final CbStatusTone tone;

  /// Said by the words too, so it never carries meaning alone.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final (fill, ink) = switch (tone) {
      CbStatusTone.soon => (cb.accent, cb.onAccent),
      CbStatusTone.overdue => (cb.danger, cb.onDanger),
    };
    final style = context.cbText.bodySm.copyWith(
      color: ink,
      fontWeight: FontWeight.w500,
    );
    final icon = this.icon;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        // Half the height of one line: a pill; several lines: a rounded box.
        borderRadius: BorderRadius.circular(CbRadius.md),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          icon == null ? CbSpace.s2 : 6,
          2,
          CbSpace.s2,
          2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                // Centres the icon on the first line of text.
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 16, color: ink),
              ),
              const SizedBox(width: CbSpace.s1),
            ],
            Flexible(child: Text(label, style: style)),
          ],
        ),
      ),
    );
  }
}
