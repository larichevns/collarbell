import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../theme/collarbell_theme.dart';

/// "See the plan", under an AI-limit error where the screen has room for it:
/// the plan screen opens above the tabs, and Back returns here. A compact
/// outlined button at the error's left edge.
class OpenPlanButton extends StatelessWidget {
  const OpenPlanButton({super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('openPlan'),
    style: cbCompactOutlinedButtonStyle,
    onPressed: () => context.push(AppRoutes.householdPlan),
    icon: const Icon(Symbols.workspace_premium_rounded),
    label: Text(context.l10n.householdPlanOpen),
  );
}
