import 'package:flutter/widgets.dart';

/// How long scrolling to a field with an error takes.
const revealDuration = Duration(milliseconds: 300);

/// Validates every field of [form] and returns the contexts of the fields
/// that have an error. The forms build all their fields (no lazy lists), so
/// fields scrolled out of view are checked too.
List<BuildContext> invalidFields(FormState form) => [
  for (final field in form.validateGranularly()) field.context,
];

/// Scrolls so the topmost of [contexts] is in view: after a failed save the
/// user sees the first field to fix, wherever the form was scrolled.
void revealTopmost(Iterable<BuildContext> contexts) {
  BuildContext? topmost;
  double? topmostY;
  for (final context in contexts) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) continue;
    final y = box.localToGlobal(Offset.zero).dy;
    if (topmostY == null || y < topmostY) {
      topmost = context;
      topmostY = y;
    }
  }
  if (topmost != null) {
    Scrollable.ensureVisible(topmost, alignment: 0.2, duration: revealDuration);
  }
}
