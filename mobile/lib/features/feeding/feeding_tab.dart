import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../household/current_household.dart';
import '../pets/pet.dart';
import 'feeding.dart';
import 'feeding_labels.dart';
import 'feeding_repository.dart';

/// The Feeding tab of a pet: its feeding schedules. At each time a reminder
/// comes and the Today screen shows a "Fed" button.
class FeedingTab extends ConsumerWidget {
  const FeedingTab({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final schedules = ref.watch(feedingSchedulesProvider(pet.id));
    // Helpers mark feedings on Today; the schedules are for the others.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    final value = schedules.value;

    final Widget content;
    if (schedules.hasError && !schedules.isLoading) {
      content = CbErrorState(
        message: errorMessageFor(schedules.error!, l10n),
        traceId: traceIdOf(schedules.error!),
        onRetry: () => ref.invalidate(feedingSchedulesProvider(pet.id)),
      );
    } else if (value == null) {
      content = const CbLoadingState();
    } else if (value.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: CbSpace.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              canEdit ? l10n.feedingEmpty : l10n.feedingEmptyHelper,
              style: context.cbText.body.copyWith(color: context.cb.inkMuted),
            ),
            // The tab's main action, while there is nothing else.
            if (canEdit) ...[
              const SizedBox(height: CbSpace.s3),
              FilledButton.icon(
                key: const ValueKey('addFeeding'),
                onPressed: () => context.push(AppRoutes.newFeeding(pet.id)),
                icon: const Icon(Symbols.add_rounded),
                label: Text(l10n.todayAddFeeding),
              ),
            ],
          ],
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final schedule in value)
            Padding(
              padding: const EdgeInsets.only(bottom: CbSpace.s3),
              child: _ScheduleCard(
                key: ValueKey(schedule.id),
                schedule: schedule,
                onTap: canEdit
                    ? () => context.push(
                        AppRoutes.editFeeding(pet.id, schedule.id),
                      )
                    : null,
              ),
            ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(feedingSchedulesProvider(pet.id));
        try {
          await ref.read(feedingSchedulesProvider(pet.id).future);
        } catch (_) {
          // The error is shown by the error state.
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          CbSpace.s4,
          CbSpace.s4,
          CbSpace.s12,
        ),
        children: [
          CbSection(
            title: l10n.feedingTitle,
            // No schedules yet: the button is under the empty text.
            action: canEdit && !showsEmptyList(schedules)
                ? OutlinedButton.icon(
                    key: const ValueKey('addFeeding'),
                    onPressed: () => context.push(AppRoutes.newFeeding(pet.id)),
                    icon: const Icon(Symbols.add_rounded),
                    label: Text(l10n.feedingAdd),
                  )
                : null,
            child: content,
          ),
        ],
      ),
    );
  }
}

/// One schedule: its times large, then the days and what is given.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({super.key, required this.schedule, this.onTap});

  final FeedingSchedule schedule;

  /// Opens the form; null (helpers) shows the schedule only.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    final what = feedingWhat(
      l10n,
      food: schedule.food,
      amount: schedule.amount,
      unit: schedule.unit,
    );
    return CbCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CbRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(CbSpace.s4),
          child: Row(
            children: [
              Icon(
                Symbols.restaurant_rounded,
                color: schedule.active ? cb.primaryText : cb.inkDisabled,
              ),
              const SizedBox(width: CbSpace.s3),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          for (final time in schedule.times)
                            timeLabel(context, time),
                        ].join(' · '),
                        style: text.subtitle,
                      ),
                      Text(
                        [
                          feedingDaysLabel(l10n, schedule.days),
                          if (!schedule.active) l10n.feedingPaused,
                        ].join(' · '),
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                      ),
                      if (what != null)
                        Text(
                          what,
                          style: text.bodySm,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              if (onTap != null) const Icon(Symbols.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
