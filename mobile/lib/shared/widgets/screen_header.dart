import 'package:flutter/material.dart';

import '../../theme/collarbell_theme.dart';

/// The title block at the top of a tab: optional caption, then the screen
/// title in `display-lg` (one per screen).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CbSpace.s4,
        CbSpace.s8,
        CbSpace.s4,
        CbSpace.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caption != null) ...[
            Text(
              caption,
              style: context.cbText.caption.copyWith(
                color: context.cb.inkMuted,
              ),
            ),
            const SizedBox(height: CbSpace.s1),
          ],
          Semantics(
            header: true,
            child: Text(title, style: context.cbText.displayLg),
          ),
        ],
      ),
    );
  }
}
