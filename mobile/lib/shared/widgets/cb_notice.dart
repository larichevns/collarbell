import 'package:flutter/material.dart';

import '../../theme/collarbell_theme.dart';

enum CbNoticeKind {
  /// Neutral information on the light blue `sunken` background.
  info,

  /// Something to keep in mind before going on, e.g. that photos go to a
  /// free AI tier: `accent-soft` (cream) background with a 1.5 px `accent`
  /// (yellow) border; the icon and the text stay `ink`.
  warning,

  /// A failure: `danger-soft` background, always with an icon and words.
  error,
}

/// A short message in a rounded box with an icon, e.g. a form error or the
/// passport disclaimer.
class CbNotice extends StatelessWidget {
  const CbNotice({
    super.key,
    required this.message,
    this.kind = CbNoticeKind.info,
  });

  const CbNotice.warning({super.key, required this.message})
    : kind = CbNoticeKind.warning;

  const CbNotice.error({super.key, required this.message})
    : kind = CbNoticeKind.error;

  final String message;
  final CbNoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final (background, icon, iconColor) = switch (kind) {
      CbNoticeKind.info => (cb.sunken, Symbols.info_rounded, cb.inkMuted),
      CbNoticeKind.warning => (cb.accentSoft, Symbols.warning_rounded, cb.ink),
      CbNoticeKind.error => (cb.dangerSoft, Symbols.error_rounded, cb.danger),
    };
    return Semantics(
      liveRegion: kind == CbNoticeKind.error,
      child: Container(
        padding: const EdgeInsets.all(CbSpace.s3),
        decoration: BoxDecoration(
          color: background,
          border: kind == CbNoticeKind.warning
              ? Border.all(color: cb.accent, width: CbSize.borderWidth)
              : null,
          borderRadius: BorderRadius.circular(CbRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: CbSpace.s2),
            Expanded(
              child: Text(
                message,
                style: context.cbText.body.copyWith(color: cb.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
