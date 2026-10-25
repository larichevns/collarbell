import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_action_card.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../ai/ai_repository.dart';
import '../ai/widgets/ai_status_refresher.dart';
import '../ai/widgets/scan_entry.dart';
import '../household/current_household.dart';
import '../pets/pet.dart';
import 'care.dart';
import 'care_labels.dart';
import 'care_repository.dart';
import 'care_rules.dart';
import 'widgets/plan_row.dart';
import 'widgets/record_row.dart';

/// The Health tab: notes to AI waiting to be checked (or failed), the care
/// plan, grouped by status (overdue, due soon, upcoming, then finished or
/// paused, folded), and the history of records with a filter by kind. With
/// AI on the server, the history can also be scanned from the passport or
/// written in words.
class HealthTab extends ConsumerStatefulWidget {
  const HealthTab({super.key, required this.pet});

  final Pet pet;

  @override
  ConsumerState<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends ConsumerState<HealthTab> {
  /// The kind the history is filtered by; null shows every record.
  CareKind? _filter;

  /// Finished and paused plans are folded until the user asks for them.
  var _showInactive = false;

  String get _petId => widget.pet.id;

  /// A plan from the presets for the pet's species, or from scratch.
  void _addPlan() => context.push(AppRoutes.carePresets(_petId));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Helpers mark plans done; adding and changing is for the others.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    final plansEmpty = showsEmptyList(ref.watch(carePlansProvider(_petId)));
    final historyEmpty = showsEmptyList(ref.watch(careRecordsProvider(_petId)));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(carePlansProvider(_petId));
        ref.invalidate(careRecordsProvider(_petId));
        ref.invalidate(petNotesProvider(_petId));
        try {
          await Future.wait([
            ref.read(carePlansProvider(_petId).future),
            ref.read(careRecordsProvider(_petId).future),
          ]);
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
          // Notes written here wait here, like scans on the Passport tab.
          if (canEdit) NoteEntry(petId: _petId),
          CbSection(
            title: l10n.healthPlansTitle,
            // No plans yet: the button is under the empty text, as the
            // tab's main action.
            action: canEdit && !plansEmpty
                ? OutlinedButton.icon(
                    key: const ValueKey('addPlan'),
                    onPressed: _addPlan,
                    icon: const Icon(Symbols.add_rounded),
                    label: Text(l10n.healthPlansAdd),
                  )
                : null,
            child: _plans(context, canEdit: canEdit),
          ),
          const SizedBox(height: CbSpace.s8),
          CbSection(
            title: l10n.healthHistoryTitle,
            // Asks again whether the server has AI when that couldn't be
            // loaded and the user comes back. No records yet: the ways to
            // add them are cards under the empty text instead.
            action: !canEdit || historyEmpty
                ? null
                : AiStatusRefresher(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Past records can also be read from photos of
                        // the paper passport, or from a note written or
                        // dictated, when the server has AI.
                        // Little room beside "History": round outlined
                        // buttons, their words in the tooltips.
                        if (ref.watch(aiStatusProvider).value?.configured ??
                            false) ...[
                          IconButton.outlined(
                            style: cbOutlinedIconButtonStyle(context),
                            tooltip: l10n.scanFromPassport,
                            icon: const Icon(Symbols.document_scanner_rounded),
                            onPressed: () => openScan(context, _petId),
                          ),
                          const SizedBox(width: CbSpace.s2),
                          IconButton.outlined(
                            style: cbOutlinedIconButtonStyle(context),
                            tooltip: l10n.noteTitle,
                            icon: const Icon(Symbols.edit_note_rounded),
                            onPressed: () => openNote(context, _petId),
                          ),
                          const SizedBox(width: CbSpace.s2),
                        ],
                        // On the narrowest phones with large text, its words
                        // wrap rather than push the row past the edge.
                        Flexible(
                          child: OutlinedButton.icon(
                            key: const ValueKey('addRecord'),
                            onPressed: () =>
                                context.push(AppRoutes.newCareRecord(_petId)),
                            icon: const Icon(Symbols.add_rounded),
                            label: Text(l10n.healthHistoryAdd),
                          ),
                        ),
                      ],
                    ),
                  ),
            child: _history(context, canEdit: canEdit),
          ),
        ],
      ),
    );
  }

  Widget _plans(BuildContext context, {required bool canEdit}) {
    final l10n = context.l10n;
    final plans = ref.watch(carePlansProvider(_petId));
    final value = plans.value;
    // A failed reload shows the error, not the old list: a plan just
    // marked done would still look due.
    if (plans.hasError && !plans.isLoading) {
      return CbErrorState(
        message: errorMessageFor(plans.error!, l10n),
        traceId: traceIdOf(plans.error!),
        onRetry: () => ref.invalidate(carePlansProvider(_petId)),
      );
    }
    if (value == null) {
      return const CbLoadingState();
    }
    if (value.isEmpty) {
      if (!canEdit) return _MutedText(l10n.healthPlansEmptyHelper);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MutedText(l10n.healthPlansEmpty),
          const SizedBox(height: CbSpace.s3),
          FilledButton.icon(
            key: const ValueKey('addPlan'),
            onPressed: _addPlan,
            icon: const Icon(Symbols.add_rounded),
            label: Text(l10n.healthPlansAdd),
          ),
        ],
      );
    }

    final groups = groupPlans(value);
    final inactive = groups[CareStatus.inactive] ?? const <CarePlan>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final status in groups.keys)
          if (status != CareStatus.inactive)
            _PlanGroup(
              key: ValueKey(status),
              title: planGroupLabel(l10n, status),
              plans: groups[status]!,
              petId: _petId,
              canEdit: canEdit,
            ),
        if (inactive.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            // The arrow shows whether the group is open; screen readers
            // hear it as "expanded" or "collapsed".
            child: Semantics(
              expanded: _showInactive,
              child: TextButton.icon(
                style: cbInlineTextButtonStyle,
                onPressed: () => setState(() => _showInactive = !_showInactive),
                icon: Icon(
                  _showInactive
                      ? Symbols.expand_less_rounded
                      : Symbols.expand_more_rounded,
                ),
                label: Text(l10n.healthInactiveToggle(inactive.length)),
              ),
            ),
          ),
          // The button above is this group's heading.
          if (_showInactive)
            _PlanGroup(
              key: const ValueKey(CareStatus.inactive),
              plans: inactive,
              petId: _petId,
              canEdit: canEdit,
            ),
        ],
      ],
    );
  }

  Widget _history(BuildContext context, {required bool canEdit}) {
    final l10n = context.l10n;
    final records = ref.watch(careRecordsProvider(_petId));
    final value = records.value;
    if (records.hasError && !records.isLoading) {
      return CbErrorState(
        message: errorMessageFor(records.error!, l10n),
        traceId: traceIdOf(records.error!),
        onRetry: () => ref.invalidate(careRecordsProvider(_petId)),
      );
    }
    if (value == null) {
      return const CbLoadingState();
    }
    if (value.isEmpty) {
      if (!canEdit) return _MutedText(l10n.healthHistoryEmptyHelper);
      final ai = ref.watch(aiStatusProvider).value?.configured ?? false;
      // The ways to fill the history, as cards: by hand, and with AI
      // (photos of the passport, or a note) when the server has it.
      return AiStatusRefresher(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MutedText(l10n.healthHistoryEmpty),
            const SizedBox(height: CbSpace.s3),
            if (ai) ...[
              CbActionCard(
                key: const ValueKey('historyScan'),
                icon: Symbols.document_scanner_rounded,
                title: l10n.scanFromPassport,
                hint: l10n.homeQuickScanHint,
                onTap: () => openScan(context, _petId),
              ),
              const SizedBox(height: CbSpace.s2),
              CbActionCard(
                key: const ValueKey('historyNote'),
                icon: Symbols.edit_note_rounded,
                title: l10n.noteTitle,
                hint: l10n.homeQuickNoteHint,
                onTap: () => openNote(context, _petId),
              ),
              const SizedBox(height: CbSpace.s2),
            ],
            CbActionCard(
              key: const ValueKey('historyAdd'),
              icon: Symbols.add_rounded,
              title: l10n.healthHistoryAdd,
              hint: l10n.healthHistoryAddHint,
              onTap: () => context.push(AppRoutes.newCareRecord(_petId)),
            ),
          ],
        ),
      );
    }

    // Chips only for the kinds the history has, in the usual order. A
    // filter whose last record was deleted falls back to "All".
    final kinds = [
      for (final kind in CareKind.values)
        if (value.any((record) => record.kind == kind)) kind,
    ];
    final filter = kinds.contains(_filter) ? _filter : null;
    final shown = [
      for (final record in value)
        if (filter == null || record.kind == filter) record,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kinds.length > 1) ...[
          Wrap(
            spacing: CbSpace.s2,
            runSpacing: CbSpace.s2,
            children: [
              ChoiceChip(
                label: Text(l10n.healthFilterAll),
                selected: filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final kind in kinds)
                ChoiceChip(
                  label: Text(careKindLabel(l10n, kind)),
                  selected: filter == kind,
                  onSelected: (_) => setState(() => _filter = kind),
                ),
            ],
          ),
          const SizedBox(height: CbSpace.s3),
        ],
        CbCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const Divider(indent: _rowIndent),
                RecordRow(
                  key: ValueKey(shown[i].id),
                  record: shown[i],
                  onTap: () =>
                      context.push(AppRoutes.careRecord(_petId, shown[i].id)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Dividers start under the text, not under the kind icon.
const _rowIndent = CbSpace.s4 + CbSize.avatarMd + CbSpace.s3;

/// One status group: its title, then the plans in a card.
class _PlanGroup extends StatelessWidget {
  const _PlanGroup({
    super.key,
    required this.plans,
    required this.petId,
    required this.canEdit,
    this.title,
  });

  /// Null when something else heads the group.
  final String? title;
  final List<CarePlan> plans;
  final String petId;

  /// A tap opens the plan's form; helpers only mark plans done.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final title = this.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: CbSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(
                title,
                style: context.cbText.label.copyWith(color: cb.inkMuted),
              ),
            ),
            const SizedBox(height: CbSpace.s2),
          ],
          CbCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < plans.length; i++) ...[
                  if (i > 0) const Divider(indent: _rowIndent),
                  PlanRow(
                    key: ValueKey(plans[i].id),
                    plan: plans[i],
                    onTap: canEdit
                        ? () => context.push(
                            AppRoutes.editCarePlan(petId, plans[i].id),
                          )
                        : null,
                    // Finished and paused plans can't be marked done; the
                    // form turns them on again.
                    onDone: plans[i].active
                        ? () => context.push(
                            AppRoutes.carePlanDone(petId, plans[i].id),
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.cbText.body.copyWith(color: context.cb.inkMuted),
  );
}
