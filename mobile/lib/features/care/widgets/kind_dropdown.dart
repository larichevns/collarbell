import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/cb_text_field.dart';
import '../../../theme/collarbell_theme.dart';
import '../care.dart';
import '../care_labels.dart';

/// The kind of care, with its icon. A form field, so a server error on
/// "kind" shows under it.
class KindDropdown extends StatelessWidget {
  const KindDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final CareKind value;
  final ValueChanged<CareKind> onChanged;
  final FormFieldValidator<CareKind>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    return DropdownButtonFormField<CareKind>(
      icon: cbDropdownIcon,
      initialValue: value,
      isExpanded: true,
      validator: validator,
      // Body text, like the text fields (Material's default is bolder).
      style: context.cbText.body.copyWith(color: cb.ink),
      items: [
        for (final kind in CareKind.values)
          DropdownMenuItem(
            value: kind,
            child: Row(
              children: [
                Icon(careKindIcon(kind), color: cb.inkMuted),
                const SizedBox(width: CbSpace.s3),
                Expanded(
                  child: Text(
                    careKindLabel(l10n, kind),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: enabled
          ? (kind) {
              if (kind != null) onChanged(kind);
            }
          : null,
    );
  }
}
