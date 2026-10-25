import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'confirm_dialog.dart';

/// Asks "Leave without saving?" before Back throws away what was typed on a
/// form, and keeps Back from doing anything while [busy] (saving: the save
/// goes on, and the lists would show the item before it).
///
/// [changed] is asked when Back is pressed, not when the form is built:
/// typing doesn't rebuild the form. A save that succeeds closes the screen
/// with `Navigator.pop`, which this lets through. The tab bar and Today's
/// first steps ask the guards too ([changedInView], [anyChanged],
/// [busyInView], [confirmInView]): they drop screens without a Back.
class LeaveGuard extends StatefulWidget {
  const LeaveGuard({
    super.key,
    required this.changed,
    this.busy = false,
    this.rebuildsOnChange = false,
    this.confirm,
    required this.child,
  });

  final bool Function() changed;
  final bool busy;

  /// The screen rebuilds whenever [changed] may answer otherwise (it calls
  /// `setState` as it is typed in): Back, and iOS's back swipe, then leave
  /// at once while nothing would be lost, and are held only while something
  /// would be (or while [busy]). Without it Back is always held, and
  /// [changed] is asked when it is pressed; iOS's back swipe is off.
  final bool rebuildsOnChange;

  /// Asks whether to leave and lose the changes, in the screen's own words;
  /// "Leave without saving?" by default ([confirmLeave]). True to leave.
  final Future<bool> Function(BuildContext context)? confirm;

  final Widget child;

  /// Whether a form on the tab in view would lose what was typed. Forms on
  /// the other tabs keep it: those tabs stay as they are.
  static bool changedInView() => _LeaveGuardState._live.any(
    (guard) => guard._inView && guard.widget.changed(),
  );

  /// Whether a form on any tab would lose what was typed.
  static bool anyChanged() =>
      _LeaveGuardState._live.any((guard) => guard.widget.changed());

  /// Whether a screen on the tab in view is [busy] (saving, deleting the
  /// account): the tab bar doesn't drop it either, as Back doesn't.
  static bool busyInView() =>
      _LeaveGuardState._live.any((guard) => guard._inView && guard.widget.busy);

  /// Asks before the tab bar drops the screens of the tab in view, in the
  /// words of the screen that would lose something ([confirm]), else
  /// "Leave without saving?". True when the user chooses to leave.
  static Future<bool> confirmInView(BuildContext context) {
    for (final guard in _LeaveGuardState._live) {
      if (guard._inView && guard.widget.changed()) {
        return (guard.widget.confirm ?? confirmLeave)(context);
      }
    }
    return confirmLeave(context);
  }

  @override
  State<LeaveGuard> createState() => _LeaveGuardState();
}

class _LeaveGuardState extends State<LeaveGuard> {
  static final _live = <_LeaveGuardState>{};

  /// On the tab in view, also under another screen of that tab (an editor
  /// opened over the form): tapping the tab again drops it too. The tabs
  /// not in view keep their navigators with tickers off.
  bool get _inView {
    if (!mounted) return false;
    final navigator = Navigator.maybeOf(context);
    return TickerMode.getNotifier(navigator?.context ?? context).value;
  }

  @override
  void initState() {
    super.initState();
    _live.add(this);
  }

  @override
  void dispose() {
    _live.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: widget.rebuildsOnChange && !widget.busy && !widget.changed(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || widget.busy) return;
        final navigator = Navigator.of(context);
        final confirm = widget.confirm ?? confirmLeave;
        if (widget.changed() && !await confirm(context)) return;
        navigator.pop(result);
      },
      child: widget.child,
    );
  }
}

/// "Leave without saving?" — true when the user chooses to leave.
Future<bool> confirmLeave(BuildContext context) {
  final l10n = context.l10n;
  return confirmDestructive(
    context,
    title: l10n.leaveTitle,
    message: l10n.leaveBody,
    confirmLabel: l10n.leaveConfirm,
  );
}

/// Whether a form's values differ from those it opened with: both are the
/// lists a form's `_values()` returns, compared item by item.
bool valuesChanged(List<Object?> opened, List<Object?> now) =>
    !listEquals(opened, now);
