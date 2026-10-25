import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/cb_card.dart';
import '../../../shared/widgets/cb_section.dart';
import '../../../shared/widgets/cb_status_tag.dart';
import '../../../theme/collarbell_theme.dart';
import '../../household/current_household.dart';
import '../../pets/widgets/pet_avatar.dart';
import '../visit.dart';
import '../visit_labels.dart';

/// Planned visits on the Today screen: past ones first ("How did it go?"),
/// then the coming ones. "All visits" opens every visit; "+" adds one (not
/// for helpers).
class TodayVisitsSection extends ConsumerWidget {
  const TodayVisitsSection({
    super.key,
    required this.today,
    required this.visits,
  });

  final DateTime today;
  final List<TodayVisit> visits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return CbSection(
      title: l10n.todayVisitsTitle,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('allVisits'),
            onPressed: () => context.push(AppRoutes.visits),
            icon: const Icon(Symbols.event_rounded),
            label: Text(l10n.todayVisitsAll),
          ),
          // Little room beside the title: "+" alone, its words in the
          // tooltip.
          if (ref.watch(householdPermissionsProvider).canEdit) ...[
            const SizedBox(width: CbSpace.s2),
            IconButton.outlined(
              key: const ValueKey('addVisit'),
              style: cbOutlinedIconButtonStyle(context),
              tooltip: l10n.visitAdd,
              onPressed: () => context.push(AppRoutes.newVisit),
              icon: const Icon(Symbols.add_rounded),
            ),
          ],
        ],
      ),
      child: visits.isEmpty
          ? Text(
              l10n.todayVisitsEmpty,
              style: context.cbText.body.copyWith(color: context.cb.inkMuted),
            )
          : CbCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < visits.length; i++) ...[
                    if (i > 0) const Divider(indent: CbSpace.s4),
                    TodayVisitRow(
                      key: ValueKey(visits[i].id),
                      visit: visits[i],
                      today: today,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// One planned visit: its kind, what for, when and where, a "Mark how it
/// went" tag once it is past, and the pets' faces. A tap opens the visit.
/// Home shows the next visit with it too, with a [chevron] like its other
/// rows.
class TodayVisitRow extends StatelessWidget {
  const TodayVisitRow({
    super.key,
    required this.visit,
    required this.today,
    this.chevron = false,
  });

  final TodayVisit visit;
  final DateTime today;

  /// The arrow at the end, centred, as in Home's "Right now".
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    final past = visit.daysAway < 0;
    final location = visit.location;
    return InkWell(
      onTap: () => context.push(AppRoutes.visit(visit.id)),
      child: Padding(
        padding: const EdgeInsets.all(CbSpace.s4),
        child: Row(
          crossAxisAlignment: chevron
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Icon(visitTypeIcon(visit.type), color: cb.primaryText),
            const SizedBox(width: CbSpace.s3),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visit.title, style: text.subtitle),
                    Text(
                      visitWhenLabel(context, visit.date, visit.time, today),
                      style: text.bodySm.copyWith(color: cb.inkMuted),
                    ),
                    if (location != null)
                      Text(
                        location,
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // A past visit not marked yet: a yellow "check this" tag.
                    if (past)
                      Padding(
                        padding: const EdgeInsets.only(top: CbSpace.s1),
                        child: CbStatusTag.soon(
                          l10n.todayVisitMarkHowItWent,
                          icon: Symbols.edit_note_rounded,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CbSpace.s2),
            // The pets' faces, overlapping a little when there are several.
            SizedBox(
              height: CbSize.avatarSm,
              width:
                  CbSize.avatarSm +
                  (visit.pets.length - 1).clamp(0, 2) * CbSize.avatarSm * 0.6,
              child: Stack(
                children: [
                  for (var i = 0; i < visit.pets.length && i < 3; i++)
                    Positioned(
                      left: i * CbSize.avatarSm * 0.6,
                      child: PetAvatar(
                        name: visit.pets[i].name,
                        photo: visit.pets[i].photo,
                        size: CbSize.avatarSm,
                      ),
                    ),
                ],
              ),
            ),
            if (chevron) ...[
              const SizedBox(width: CbSpace.s2),
              Icon(Symbols.chevron_right_rounded, color: cb.inkMuted),
            ],
          ],
        ),
      ),
    );
  }
}
