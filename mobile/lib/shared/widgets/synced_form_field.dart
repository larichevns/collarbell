import 'package:flutter/widgets.dart';

/// A [FormField] whose value follows [initialValue] when the parent changes
/// it.
///
/// A plain [FormField] reads `initialValue` only once. The date and time
/// fields get their value from the form, which sometimes sets it itself,
/// e.g. the next due date worked out from the last time; the field then has
/// to show (and validate) the new value.
class SyncedFormField<T> extends FormField<T> {
  const SyncedFormField({
    super.key,
    required super.builder,
    super.initialValue,
    super.validator,
    super.enabled,
  });

  @override
  FormFieldState<T> createState() => _SyncedFormFieldState<T>();
}

class _SyncedFormFieldState<T> extends FormFieldState<T> {
  @override
  void didUpdateWidget(SyncedFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Called while building, so the value is set without setState.
    if (widget.initialValue != oldWidget.initialValue) {
      setValue(widget.initialValue);
    }
  }
}
