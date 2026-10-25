import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/collarbell_theme.dart';
import 'synced_form_field.dart';

/// A calendar date with its label above it, like [CbTextField]. Tapping
/// opens the date picker; the clear button empties the date.
///
/// Dates are calendar dates (midnight). By default they can't be in the
/// future: pets aren't born, chipped or vaccinated tomorrow. Dates that look
/// ahead (the next due date, "valid until") pass a later [lastDate].
class CbDateField extends StatelessWidget {
  const CbDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.helperText,
    this.validator,
    this.enabled = true,
    this.clearable = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  /// The earliest date the picker offers; [earliestDate] by default.
  final DateTime? firstDate;

  /// The latest date the picker offers; today by default.
  final DateTime? lastDate;

  /// A hint under the field, e.g. how a date was worked out.
  final String? helperText;
  final FormFieldValidator<DateTime>? validator;
  final bool enabled;

  /// False for a required date: no clear button.
  final bool clearable;

  /// Old enough for any pet's or passport's dates.
  static final earliestDate = DateTime(1980);

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    return SyncedFormField<DateTime>(
      initialValue: value,
      validator: validator,
      builder: (field) {
        final date = field.value;
        Future<void> pick() async {
          final first = firstDate ?? earliestDate;
          final last = lastDate ?? CbDateField.today();
          var initial = date ?? CbDateField.today();
          if (initial.isBefore(first)) initial = first;
          if (initial.isAfter(last)) initial = last;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: first,
            lastDate: last,
          );
          // The picker sits above the screen; if the screen closed while it
          // was open, the field is gone and the date has nowhere to go.
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
                  isEmpty: date == null,
                  decoration: InputDecoration(
                    enabled: enabled,
                    hintText: l10n.dateNotSet,
                    helperText: helperText,
                    helperMaxLines: 3,
                    errorText: field.errorText,
                    suffixIcon: date == null || !clearable
                        ? const Icon(Symbols.calendar_today_rounded)
                        : IconButton(
                            tooltip: l10n.dateClear,
                            icon: const Icon(Symbols.close_rounded),
                            onPressed: enabled ? clear : null,
                          ),
                  ),
                  child: date == null
                      ? null
                      : Text(l10n.dateMedium(date), style: text.body),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
