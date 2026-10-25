import 'package:flutter/material.dart';

import '../../theme/collarbell_theme.dart';

/// A call to action as a card, where several things can be started (an
/// empty screen's first steps, Home's quick actions, the onboarding): an
/// icon in a mint circle, a title, a one-line "why" and a chevron. The
/// whole card is one button, so the words are as easy to hit as the icon.
///
/// [CbActionCard.compact] is the small one of a two-column grid: the icon
/// on top and no chevron; a grid row grows with its longest words, so
/// nothing is cut at 320 dp or with large text. [primary] marks the one
/// thing to do first: the card is mint and its circle the bright green.
class CbActionCard extends StatelessWidget {
  const CbActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.hint,
    this.primary = false,
  }) : compact = false;

  const CbActionCard.compact({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.hint,
  }) : compact = true,
       primary = false;

  final IconData icon;
  final String title;

  /// Why to do it, in a few words ("We'll remind you when to feed").
  final String? hint;
  final VoidCallback? onTap;
  final bool compact;
  final bool primary;

  /// As tall as a list row with an avatar: a comfortable target.
  static const minHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final text = context.cbText;
    final hint = this.hint;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(CbRadius.lg),
      side: BorderSide(color: primary ? cb.primarySoft : cb.line),
    );
    // The circle: mint with a dark green icon; on the primary card, where
    // the card itself is mint, the bright green with the white icon.
    final circle = Container(
      width: CbSize.avatarMd,
      height: CbSize.avatarMd,
      decoration: BoxDecoration(
        color: primary ? cb.primary : cb.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: primary ? cb.onPrimary : cb.primaryText),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: text.subtitle.copyWith(color: cb.ink)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint, style: text.bodySm.copyWith(color: cb.inkMuted)),
        ],
      ],
    );
    final Widget content = compact
        ? Padding(
            padding: const EdgeInsets.all(CbSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                circle,
                const SizedBox(height: CbSpace.s2),
                words,
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CbSpace.s4,
              vertical: CbSpace.s3,
            ),
            child: Row(
              children: [
                circle,
                const SizedBox(width: CbSpace.s3),
                Expanded(child: words),
                const SizedBox(width: CbSpace.s2),
                Icon(Symbols.chevron_right_rounded, color: cb.inkMuted),
              ],
            ),
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CbRadius.lg),
        boxShadow: context.cbShadows.card,
      ),
      child: Material(
        color: primary ? cb.primarySoft : cb.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        // One button for screen readers: the title, then the hint.
        child: MergeSemantics(
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: minHeight),
                child: Align(
                  // In a grid row the cards are as tall as the tallest:
                  // their icons line up at the top.
                  alignment: compact
                      ? AlignmentDirectional.topStart
                      : AlignmentDirectional.centerStart,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [CbActionCard.compact] cards two to a row; a row is as tall as its
/// taller card, so the cards of a row line up whatever their words. Where
/// two don't fit (a narrow phone with large text, where a long word would
/// break in the middle), one card a row, in the full layout.
class CbActionGrid extends StatelessWidget {
  const CbActionGrid({super.key, required this.cards});

  final List<CbActionCard> cards;

  /// The width two cards a row need at the usual text size.
  static const twoColumnsFrom = 280.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        return constraints.maxWidth >= scaler.scale(twoColumnsFrom)
            ? _twoColumns()
            : _oneColumn();
      },
    );
  }

  Widget _oneColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: CbSpace.s2),
        CbActionCard(
          key: cards[i].key,
          icon: cards[i].icon,
          title: cards[i].title,
          hint: cards[i].hint,
          onTap: cards[i].onTap,
          primary: cards[i].primary,
        ),
      ],
    ],
  );

  Widget _twoColumns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) const SizedBox(height: CbSpace.s2),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: CbSpace.s2),
                // An odd last card keeps half the width, as in the rows
                // above.
                Expanded(
                  child: i + 1 < cards.length
                      ? cards[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
