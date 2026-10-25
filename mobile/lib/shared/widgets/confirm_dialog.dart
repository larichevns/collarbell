import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/collarbell_theme.dart';

/// Asks before something that can't be undone, such as deleting. Returns
/// true when the user confirms. The confirm button is `danger` red, with
/// words that say what happens ("Delete"), never just "OK".
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: context.cb.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
