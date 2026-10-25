import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/app_events.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/cb_card.dart';
import '../../../shared/widgets/cb_section.dart';
import '../../../theme/collarbell_theme.dart';
import '../../household/current_household.dart';
import '../../notifications/notifications_repository.dart';
import '../../pets/widgets/pet_avatar.dart';
import '../../today/today_repository.dart';
import '../feeding.dart';
import '../feeding_labels.dart';
import '../feeding_repository.dart';

/// Today's feedings by time of day. Each pet has a "Fed" button; "All fed"
/// marks every pet of that time at once (spec 5.2). A mark shows when it was
/// made and by whom; tapping it offers to take it back. Two phones can't
/// mark the same feeding twice: the second one learns who was first.
///
/// Home shows the next feeding with it too ([next]), so marking works the
/// same there, conflicts and offline copies included.
class TodayFeedingSection extends ConsumerStatefulWidget {
  const TodayFeedingSection({
    super.key,
    required this.date,
    required this.items,
    this.next = false,
  });

  /// "Today" in the household's time zone: the date the marks are for.
  final DateTime date;
  final List<TodayFeeding> items;

  /// Home's "Right now": of [items] (all of today's) only the next time to
  /// feed ([nextFeeding], by the marks Today loaded, so the time stays
  /// until Today reloads with the new ones). No heading of its own (it sits
  /// under Home's), and the time says what it is: "Feeding at 08:00".
  final bool next;

  @override
  ConsumerState<TodayFeedingSection> createState() =>
      _TodayFeedingSectionState();
}

class _TodayFeedingSectionState extends ConsumerState<TodayFeedingSection> {
  /// Feedings being marked or unmarked now, by [_key].
  final _busy = <String>{};

  /// Marks made (or taken back) here, shown until Today reloads with them.
  final _local = <String, FeedingMark?>{};

  static String _key(TodayFeeding item) =>
      '${item.routineId}@${minutesOf(item.time)}';

  @override
  void didUpdateWidget(TodayFeedingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fresh data from the server: it knows the marks now.
    if (!identical(oldWidget.items, widget.items)) _local.clear();
  }

  FeedingMark? _markOf(TodayFeeding item) {
    final key = _key(item);
    return _local.containsKey(key) ? _local[key] : item.mark;
  }

  /// Today and the reminder list reload; through the [container], so it
  /// works after this section is gone.
  static void _refresh(ProviderContainer container) {
    container.invalidate(todayProvider);
    container.invalidate(reminderLogProvider);
  }

  /// Marks [items] one after another. Feedings someone else marked first
  /// show their mark, and a message says who it was.
  Future<void> _mark(List<TodayFeeding> items, {bool skipped = false}) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final feeding = ref.read(feedingRepositoryProvider);
    setState(() => _busy.addAll(items.map(_key)));
    final taken = <FeedingMark>[];
    var marked = 0;
    Object? failure;
    for (final item in items) {
      try {
        final mark = await feeding.mark(
          item.routineId,
          widget.date,
          item.time,
          skipped: skipped,
        );
        marked++;
        if (mounted) setState(() => _local[_key(item)] = mark);
      } on FeedingAlreadyMarked catch (conflict) {
        taken.add(conflict.mark);
        if (mounted) setState(() => _local[_key(item)] = conflict.mark);
      } catch (error) {
        debugPrint('Marking the feeding failed: $error');
        failure = error;
        // No answer from the server: the next pets would each wait as long.
        if (isUnreachable(error)) break;
      }
    }
    if (mounted) setState(() => _busy.removeAll(items.map(_key)));
    // "All fed" marks two or more at once.
    if (marked > 0 && !skipped) {
      container
          .read(appEventsProvider)
          .action(items.length > 1 ? AppAction.fedAll : AppAction.fed);
    }
    if (taken.isNotEmpty && mounted) {
      final first = taken.first;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.feedingAlreadyMarked(
              first.byName ?? l10n.feedingSomeoneElse,
              TimeOfDay.fromDateTime(first.doneAt).format(context),
            ),
          ),
        ),
      );
    } else if (failure != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(failure, l10n))),
      );
    }
    _refresh(container);
  }

  /// Skips a feeding on purpose, after asking: a long press is easy to make
  /// by accident, and a skipped feeding gets no reminder.
  Future<void> _skip(TodayFeeding item) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.feedingSkipTitle(item.petName)),
        content: Text(l10n.feedingSkipBody(timeLabel(context, item.time))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.feedingSkip),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _mark([item], skipped: true);
  }

  Future<void> _undo(TodayFeeding item, FeedingMark mark) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.feedingUndoTitle(item.petName)),
        content: Text(l10n.feedingUndoBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.feedingUndo),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final feeding = ref.read(feedingRepositoryProvider);
    setState(() => _busy.add(_key(item)));
    try {
      await feeding.undo(item.routineId, mark.id);
      if (mounted) setState(() => _local[_key(item)] = null);
    } catch (error) {
      debugPrint('Taking the feeding mark back failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(_key(item)));
      _refresh(container);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slots = feedingsByTime(
      widget.next
          ? nextFeeding(widget.items) ?? const <TodayFeeding>[]
          : widget.items,
    );
    final cards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: time, value: items) in slots.entries)
          Padding(
            key: ValueKey('slot-${minutesOf(time)}'),
            // Home spaces its parts itself.
            padding: EdgeInsets.only(bottom: widget.next ? 0 : CbSpace.s3),
            child: _slot(context, time, items),
          ),
      ],
    );
    if (widget.next) return cards;
    return CbSection(title: l10n.todayFeedingTitle, child: cards);
  }

  Widget _slot(BuildContext context, TimeOfDay time, List<TodayFeeding> items) {
    final l10n = context.l10n;
    final open = [
      for (final item in items)
        if (_markOf(item) == null && !_busy.contains(_key(item))) item,
    ];
    return CbCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CbSpace.s4,
              CbSpace.s2,
              CbSpace.s4,
              0,
            ),
            // The time left, "All fed" right; on a narrow phone with large
            // text, "All fed" goes under the time, both at the start.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CbSize.controlMd),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        widget.next
                            ? l10n.homeNextFeeding(timeLabel(context, time))
                            : timeLabel(context, time),
                        style: context.cbText.subtitle,
                      ),
                    ),
                    // Two or more pets still to feed at this time. Its
                    // outline ends where the "Fed" buttons below end.
                    if (open.length > 1)
                      OutlinedButton.icon(
                        key: ValueKey('feedAll-${minutesOf(time)}'),
                        style: cbCompactOutlinedButtonStyle,
                        onPressed: () => _mark(open),
                        icon: const Icon(Symbols.done_all_rounded),
                        label: Text(l10n.feedingAll),
                      ),
                  ],
                ),
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(indent: CbSpace.s4 + CbSize.avatarSm + CbSpace.s3),
            _row(context, items[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, TodayFeeding item) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final mark = _markOf(item);
    final busy = _busy.contains(_key(item));
    final what = feedingWhat(
      l10n,
      food: item.food,
      amount: item.amount,
      unit: item.unit,
    );

    final Widget trailing;
    if (busy) {
      trailing = const Padding(
        padding: EdgeInsets.all(CbSpace.s3),
        child: SizedBox.square(
          dimension: CbSpace.s5,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (mark == null) {
      trailing = FilledButton.tonal(
        key: ValueKey('fed-${_key(item)}'),
        onPressed: () => _mark([item]),
        child: Text(l10n.feedingFed),
      );
    } else {
      // Only the time here, so a long name can't push the row off the
      // screen; who marked it goes under the pet's name.
      final at = TimeOfDay.fromDateTime(mark.doneAt).format(context);
      final icon = Icon(
        mark.skipped
            ? Symbols.do_not_disturb_on_rounded
            : Symbols.check_circle_rounded,
        // Done: the round check filled bright green, its tick white.
        fill: mark.skipped ? 0 : 1,
        color: mark.skipped ? cb.inkMuted : cb.success,
      );
      final label = Text(
        mark.skipped ? l10n.feedingSkippedAt(at) : at,
        style: text.bodySm.copyWith(color: cb.inkMuted),
      );
      // Helpers take back only their own marks.
      final canUndo = ref
          .watch(householdPermissionsProvider)
          .canTakeBack(byMe: mark.byMe);
      trailing = Semantics(
        label: mark.skipped
            ? l10n.feedingSkippedAt(at)
            : l10n.feedingFedAtSemantics(at),
        hint: canUndo ? l10n.feedingUndoHint : null,
        excludeSemantics: true,
        child: canUndo
            ? TextButton.icon(
                key: ValueKey('marked-${_key(item)}'),
                onPressed: () => _undo(item, mark),
                icon: icon,
                label: label,
              )
            : Padding(
                key: ValueKey('marked-${_key(item)}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: CbSpace.s3,
                  vertical: CbSpace.s2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(width: CbSpace.s2),
                    label,
                  ],
                ),
              ),
      );
    }
    final by = mark == null || mark.byMe
        ? null
        : l10n.feedingMarkedBy(mark.byName ?? l10n.feedingSomeoneElse);

    return InkWell(
      // Skipping a feeding on purpose (e.g. no food before surgery) is rare:
      // it sits behind a long press, and asks first.
      onLongPress: mark == null && !busy ? () => _skip(item) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          CbSpace.s2,
          CbSpace.s4,
          CbSpace.s2,
        ),
        child: Row(
          children: [
            PetAvatar(
              name: item.petName,
              photo: item.petPhoto,
              size: CbSize.avatarSm,
            ),
            const SizedBox(width: CbSpace.s3),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.petName,
                      style: text.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (what != null)
                      Text(
                        what,
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (by != null)
                      Text(
                        by,
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CbSpace.s2),
            trailing,
          ],
        ),
      ),
    );
  }
}
