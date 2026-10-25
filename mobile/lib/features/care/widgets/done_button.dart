import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/collarbell_theme.dart';

/// "Done" on a plan: the design system's mark button, a ring (1.5 px
/// `line-strong`, like every outline) with a tick (`primary-text`: a thin
/// green line on white), 44 px (`CbSize.check`). It opens the Done screen.
/// The word "Done" is its tooltip and what screen readers say; a round
/// button leaves the row's text room on a small phone, in Russian too.
class DoneButton extends StatelessWidget {
  const DoneButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return IconButton(
      tooltip: context.l10n.planDone,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(CbSize.check),
        minimumSize: const Size.square(CbSize.check),
        shape: const CircleBorder(),
        side: BorderSide(color: cb.lineStrong, width: CbSize.borderWidth),
        foregroundColor: cb.primaryText,
      ),
      icon: const Icon(Symbols.check_rounded),
    );
  }
}
