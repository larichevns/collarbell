import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../care/care_labels.dart';
import '../care/widgets/done_button.dart';
import '../care/widgets/due_line.dart';
import '../feeding/widgets/today_feeding.dart';
import '../household/current_household.dart';
import '../household/household_labels.dart';
import '../me/profile_sync.dart';
import '../notifications/widgets/push_off_notice.dart';
import '../supplies/widgets/today_shopping.dart';
import '../pets/pet_detail_screen.dart';
import '../pets/widgets/pet_avatar.dart';
import '../visits/widgets/today_visits.dart';
import 'first_steps.dart';
import 'today.dart';
import 'today_reload.dart';
import 'today_repository.dart';

/// Today's full list: today's date, today's feedings with their "Fed"
/// buttons, planned visits, what to buy, then the care of all pets that is
/// overdue, due soon or due later this month. Tapping a care item opens the
/// pet's Health tab; "Done" opens the Done screen. Home (the first tab)
/// shows the most pressing of it.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, this.now});

  /// Fixed clock for tests; defaults to the current time.
  final DateTime? now;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> with TodayReload {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = widget.now;
    final today = ref.watch(todayProvider);
    final value = today.value;
    // Once loaded, the date is the server's "today" in the household's
    // time zone: the items count their days from it.
    final date = l10n.todayDate(value?.date ?? now ?? DateTime.now());
    final group = todayGroupShown(ref, l10n);

    final Widget content;
    // A failed reload shows the error, not the old list: something just
    // marked done would still look due.
    if (today.hasError && !today.isLoading) {
      content = CbErrorState(
        message: errorMessageFor(today.error!, l10n),
        traceId: traceIdOf(today.error!),
        onRetry: () => ref.invalidate(todayProvider),
      );
    } else if (value == null) {
      content = const CbLoadingState();
    } else if (value.isEmpty) {
      content = const TodayFirstSteps();
    } else {
      final groups = groupTodayItems(value.items);
      // While it reloads (pulled, back in the app, the server back after
      // offline copies), the old list stays in view but takes no taps:
      // "Fed" on it could act on yesterday or on what is already done.
      content = IgnorePointer(
        ignoring: today.isLoading,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CbSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Feeding first: it is what today is made of, hour by hour.
              if (value.feedings.isNotEmpty) ...[
                TodayFeedingSection(date: value.date, items: value.feedings),
                const SizedBox(height: CbSpace.s3),
              ],
              // Always there: it is also the way to the list of visits.
              TodayVisitsSection(today: value.date, visits: value.visits),
              const SizedBox(height: CbSpace.s6),
              if (value.shopping.isNotEmpty) ...[
                TodayShoppingSection(items: value.shopping),
                const SizedBox(height: CbSpace.s6),
              ],
              for (final group in groups.keys)
                _Group(
                  key: ValueKey(group),
                  title: switch (group) {
                    TodayGroup.overdue => l10n.careStatusOverdue,
                    TodayGroup.dueSoon => l10n.careStatusDueSoon,
                    TodayGroup.later => l10n.todayGroupLater,
                  },
                  items: groups[group]!,
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayProvider);
            try {
              await ref.read(todayProvider.future);
            } catch (_) {
              // The error is shown by the error state.
            }
          },
          child: ListView(
            // Pull to refresh works on a short list too.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: CbSpace.s12),
            children: [
              ScreenHeader(
                // "среда, 1 октября" starts a line, so it is capitalised.
                caption: [
                  if (date.isNotEmpty)
                    date[0].toUpperCase() + date.substring(1),
                  ?group,
                ].join(' · '),
                title: l10n.todayTitle,
              ),
              const PushOffNotice(
                padding: EdgeInsets.fromLTRB(
                  CbSpace.s4,
                  0,
                  CbSpace.s4,
                  CbSpace.s4,
                ),
              ),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

/// One group, e.g. "Overdue": its title, then the items in a card.
class _Group extends StatelessWidget {
  const _Group({super.key, required this.title, required this.items});

  final String title;
  final List<TodayCareItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CbSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: context.cbText.title),
          ),
          const SizedBox(height: CbSpace.s2),
          CbCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      indent: CbSpace.s4 + CbSize.avatarMd + CbSpace.s3,
                    ),
                  TodayRow(key: ValueKey(items[i].planId), item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One due plan: the pet's avatar and name, what to do and when (in the
/// status colour), and "Done". Tapping the row opens the pet's page on its
/// Health tab.
class TodayRow extends StatelessWidget {
  const TodayRow({super.key, required this.item});

  final TodayCareItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final kind = careKindLabel(l10n, item.kind);
    return InkWell(
      // The pet's page opens on top of Today, always on its Health tab
      // (every tap makes a new page). It doesn't touch the Pets tab, where
      // a form may be open, and Back returns to Today.
      onTap: () => context.push(AppRoutes.pet(item.petId, tab: PetTab.health)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          CbSpace.s3,
          CbSpace.s4,
          CbSpace.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PetAvatar(name: item.petName, photo: item.petPhoto),
            const SizedBox(width: CbSpace.s3),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: text.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      // The kind only when the title doesn't say it already.
                      [item.petName, if (kind != item.title) kind].join(' · '),
                      style: text.bodySm.copyWith(color: context.cb.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: CbSpace.s1),
                    DueLine(
                      status: item.status,
                      daysLeft: item.daysLeft,
                      dueOn: item.nextDueOn,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CbSpace.s2),
            DoneButton(
              onPressed: () => context.push(AppRoutes.todayDone(item.planId)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The group Today (and Home) is about, for someone in more than one: which
/// household the feedings and visits below are, is not obvious then. Null
/// otherwise.
String? todayGroupShown(WidgetRef ref, AppLocalizations l10n) {
  final current = ref.watch(currentHouseholdProvider);
  final households = ref.watch(meProvider.select((me) => me.value?.households));
  final name = current?.name;
  if (name == null || households == null || households.length < 2) {
    return null;
  }
  return householdName(l10n, name, role: current?.role);
}
