import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/collarbell_theme.dart';
import 'synced_form_field.dart';

/// A time of day with its label above it, like [CbDateField]. Tapping opens
/// the time picker; the clear button empties the time.
///
/// Used where the hour matters, e.g. the tapeworm treatment before travel:
/// entry is allowed 24 to 120 hours after it.
class CbTimeField extends StatelessWidget {
  const CbTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;
  final String? helperText;
  final FormFieldValidator<TimeOfDay>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    return SyncedFormField<TimeOfDay>(
      initialValue: value,
      validator: validator,
      builder: (field) {
        final time = field.value;
        Future<void> pick() async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time ?? TimeOfDay.now(),
          );
          // The picker sits above the screen; if the screen closed while it
          // was open, the field is gone and the time has nowhere to go.
          if (picked == null || !field.mounted) return;
          field.didChange(picked);
          onChanged(picked);
        }

        void clear() {
          field.didChange(null);
          onChanged(null);
        }

        return MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: text.label),
              const SizedBox(height: CbSpace.s2),
              InkWell(
                onTap: enabled ? pick : null,
                borderRadius: BorderRadius.circular(CbRadius.md),
                child: InputDecorator(
                  isEmpty: time == null,
                  decoration: InputDecoration(
                    enabled: enabled,
                    hintText: l10n.timeNotSet,
                    helperText: helperText,
                    helperMaxLines: 3,
                    errorText: field.errorText,
                    suffixIcon: time == null
                        ? const Icon(Symbols.schedule_rounded)
                        : IconButton(
                            tooltip: l10n.timeClear,
                            icon: const Icon(Symbols.close_rounded),
                            onPressed: enabled ? clear : null,
                          ),
                  ),
                  child: time == null
                      ? null
                      : Text(time.format(context), style: text.body),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
