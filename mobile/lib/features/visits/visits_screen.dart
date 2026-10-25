import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../household/current_household.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import 'visit.dart';
import 'visit_labels.dart';
import 'visits_repository.dart';

/// All visits: the planned ones (soonest first), then the past and
/// cancelled ones (newest first).
class VisitsScreen extends ConsumerWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visits = ref.watch(visitsProvider);
    // Helpers see the visits and say how they went; adding is for others.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    final pets = {
      for (final pet in ref.watch(petsProvider).value ?? const <Pet>[])
        pet.id: pet,
    };
    final value = visits.value;

    final Widget content;
    if (visits.hasError && !visits.isLoading) {
      content = CbErrorState(
        message: errorMessageFor(visits.error!, l10n),
        traceId: traceIdOf(visits.error!),
        onRetry: () => ref.invalidate(visitsProvider),
      );
    } else if (value == null) {
      content = const CbLoadingState();
    } else if (value.isEmpty) {
      content = Column(
        children: [
          CbEmptyState(
            icon: Symbols.event_rounded,
            title: l10n.visitsEmptyTitle,
            message: canEdit
                ? l10n.visitsEmptyBody
                : l10n.visitsEmptyBodyHelper,
          ),
          // The screen's main action, right here (the button over the
          // list comes with the first visit).
          if (canEdit)
            FilledButton.icon(
              key: const ValueKey('addFirstVisit'),
              onPressed: () => context.push(AppRoutes.newVisit),
              icon: const Icon(Symbols.add_rounded),
              label: Text(l10n.visitAdd),
            ),
        ],
      );
    } else {
      final planned = [
        for (final visit in value)
          if (visit.status == VisitStatus.planned) visit,
      ];
      final past = [
        for (final visit in value)
          if (visit.status != VisitStatus.planned) visit,
      ];
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (planned.isNotEmpty)
            CbSection(
              title: l10n.visitsPlanned,
              child: _VisitList(visits: planned, pets: pets),
            ),
          if (planned.isNotEmpty && past.isNotEmpty)
            const SizedBox(height: CbSpace.s6),
          if (past.isNotEmpty)
            CbSection(
              title: l10n.visitsPast,
              child: _VisitList(visits: past, pets: pets),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.visitsTitle)),
      floatingActionButton: canEdit && showsAddOverList(visits)
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.newVisit),
              icon: const Icon(Symbols.add_rounded),
              label: Text(l10n.visitAdd),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(visitsProvider);
          try {
            await ref.read(visitsProvider.future);
          } catch (_) {
            // The error is shown by the error state.
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Room for the button over the last row.
          padding: EdgeInsets.fromLTRB(
            CbSpace.s4,
            CbSpace.s4,
            CbSpace.s4,
            canEdit ? CbSpace.s12 * 2 : CbSpace.s12,
          ),
          children: [content],
        ),
      ),
    );
  }
}

class _VisitList extends StatelessWidget {
  const _VisitList({required this.visits, required this.pets});

  final List<Visit> visits;
  final Map<String, Pet> pets;

  @override
  Widget build(BuildContext context) {
    return CbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < visits.length; i++) ...[
            if (i > 0) const Divider(indent: CbSpace.s4 + 24 + CbSpace.s3),
            VisitRow(
              key: ValueKey(visits[i].id),
              visit: visits[i],
              petNames: [for (final id in visits[i].petIds) ?pets[id]?.name],
            ),
          ],
        ],
      ),
    );
  }
}

/// One visit in a list: its type icon, title, when, and for whom.
class VisitRow extends StatelessWidget {
  const VisitRow({super.key, required this.visit, required this.petNames});

  final Visit visit;
  final List<String> petNames;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    final muted = visit.status != VisitStatus.planned;
    return InkWell(
      onTap: () => context.push(AppRoutes.visit(visit.id)),
      child: Padding(
        padding: const EdgeInsets.all(CbSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              visitTypeIcon(visit.type),
              color: muted ? cb.inkMuted : cb.primaryText,
            ),
            const SizedBox(width: CbSpace.s3),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visit.title, style: text.subtitle),
                    Text(
                      [
                        visitWhenLabel(
                          context,
                          visit.date,
                          visit.time,
                          CbDateField.today(),
                        ),
                        if (visit.status != VisitStatus.planned)
                          visitStatusLabel(l10n, visit.status),
                      ].join(' · '),
                      style: text.bodySm.copyWith(color: cb.inkMuted),
                    ),
                    if (petNames.isNotEmpty)
                      Text(
                        petNames.join(', '),
                        style: text.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            const Icon(Symbols.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
