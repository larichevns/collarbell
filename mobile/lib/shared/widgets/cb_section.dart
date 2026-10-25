import 'package:flutter/material.dart';

import '../../theme/collarbell_theme.dart';

/// A titled block of a screen: the title in `title` style, an optional
/// action on the right (e.g. "Add pages"), then the content. When the
/// title and the action don't fit side by side (a narrow phone, large
/// text), the action goes under the title.
///
/// The action is a real button: an `OutlinedButton` gets the compact style
/// ([cbCompactOutlinedButtonStyle]), so it fits beside the title and its
/// outline ends at the cards' right edge; an outlined icon button with a
/// tooltip where even that has no room. A text button left here (nothing
/// calls to action with one) has no side padding ([cbInlineTextButtonStyle]).
class CbSection extends StatelessWidget {
  const CbSection({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.titleWraps = false,
  });

  final String title;
  final Widget child;
  final Widget? action;

  /// The title wraps to more lines beside the action instead of the action
  /// going under it: for a small action (a round "+") beside a long title.
  final bool titleWraps;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    final theme = Theme.of(context);
    final title = Semantics(
      header: true,
      child: Text(this.title, style: context.cbText.title),
    );
    return Column(
      // Cards span the full width, whatever their content.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          // Keeps the title in place whether or not there is an action.
          constraints: const BoxConstraints(minHeight: CbSize.controlMd),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: action == null
                ? title
                : titleWraps
                ? Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: CbSpace.s2),
                      action,
                    ],
                  )
                : OverflowBar(
                    // Side by side: the title left, the action right.
                    // Otherwise one under the other, both at the start.
                    alignment: MainAxisAlignment.spaceBetween,
                    overflowAlignment: OverflowBarAlignment.start,
                    children: [
                      title,
                      OutlinedButtonTheme(
                        data: OutlinedButtonThemeData(
                          style: cbCompactOutlinedButtonStyle.merge(
                            theme.outlinedButtonTheme.style,
                          ),
                        ),
                        child: TextButtonTheme(
                          data: TextButtonThemeData(
                            style: cbInlineTextButtonStyle.merge(
                              theme.textButtonTheme.style,
                            ),
                          ),
                          child: action,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: CbSpace.s2),
        child,
      ],
    );
  }
}

/// One fact in a details card: a muted label above its value.
class CbDetailRow extends StatelessWidget {
  const CbDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;

  /// JetBrains Mono, for chip and passport numbers.
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final text = context.cbText;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CbSpace.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: text.caption.copyWith(color: context.cb.inkMuted),
            ),
            const SizedBox(height: CbSpace.s1),
            Text(value, style: monospace ? text.code : text.body),
          ],
        ),
      ),
    );
  }
}
