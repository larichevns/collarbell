import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../household/current_household.dart';
import '../pets/pet.dart';
import '../pets/pet_detail_screen.dart';
import '../pets/pets_repository.dart';
import 'visit.dart';
import 'visit_done_sheet.dart';
import 'visit_labels.dart';
import 'visit_refresh.dart';
import 'visits_repository.dart';

/// One visit: when, where, for whom, the reminders, and what to do with it:
/// "The visit took place", edit, cancel (or plan again), delete.
class VisitDetailScreen extends ConsumerWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visit = ref.watch(visitProvider(visitId));
    final pets = {
      for (final pet in ref.watch(petsProvider).value ?? const <Pet>[])
        pet.id: pet,
    };
    final value = visit.value;
    if (value == null) {
      return Scaffold(
        appBar: AppBar(),
        body: visit.hasError
            ? Center(
                child: CbErrorState(
                  message: errorMessageFor(visit.error!, l10n),
                  traceId: traceIdOf(visit.error!),
                  onRetry: () => ref.invalidate(visitProvider(visitId)),
                ),
              )
            : const CbLoadingState(),
      );
    }

    final text = context.cbText;
    final cb = context.cb;
    final today = CbDateField.today();
    final planned = value.status == VisitStatus.planned;
    final tookPlace = !value.date.isAfter(today);
    final location = value.location;
    final notes = value.notes;
    // Helpers say how a visit went; changing it is for the others.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;

    return Scaffold(
      appBar: AppBar(
        title: Text(value.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (canEdit &&
              !value.hasUnknownValues &&
              value.status != VisitStatus.done)
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Symbols.edit_rounded),
              onPressed: () => context.push(AppRoutes.editVisit(value.id)),
            ),
          if (canEdit)
            PopupMenuButton<_VisitAction>(
              tooltip: l10n.commonMoreActions,
              // ⋮ in Material Symbols, as every other icon.
              icon: const Icon(Symbols.more_vert_rounded),
              onSelected: (action) => switch (action) {
                _VisitAction.cancel => _setStatus(
                  context,
                  ref,
                  value,
                  VisitStatus.cancelled,
                ),
                _VisitAction.planAgain => _setStatus(
                  context,
                  ref,
                  value,
                  VisitStatus.planned,
                ),
                _VisitAction.delete => _delete(context, ref, value),
              },
              itemBuilder: (context) => [
                if (planned && !value.hasUnknownValues)
                  PopupMenuItem(
                    value: _VisitAction.cancel,
                    child: Text(l10n.visitCancel),
                  ),
                if (value.status == VisitStatus.cancelled &&
                    !value.hasUnknownValues)
                  PopupMenuItem(
                    value: _VisitAction.planAgain,
                    child: Text(l10n.visitPlanAgain),
                  ),
                PopupMenuItem(
                  value: _VisitAction.delete,
                  child: Text(
                    l10n.visitDelete,
                    style: TextStyle(color: cb.danger),
                  ),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: planned && tookPlace && !value.hasUnknownValues
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(CbSpace.s4),
                child: FilledButton.icon(
                  onPressed: () => showVisitDoneSheet(context, value),
                  icon: const Icon(Symbols.check_rounded),
                  label: Text(l10n.visitDone),
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        // Pull to refresh: another phone may have moved or marked the visit.
        onRefresh: () async {
          try {
            ref.invalidate(visitProvider(visitId));
            await ref.read(visitProvider(visitId).future);
          } catch (error) {
            // The screen keeps what it shows: the snackbar says why.
            if (context.mounted) showRefreshFailed(context, error);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(CbSpace.s4),
          children: [
            if (value.status == VisitStatus.cancelled) ...[
              CbNotice.warning(message: l10n.visitCancelledNote),
              const SizedBox(height: CbSpace.s4),
            ],
            CbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(visitTypeIcon(value.type), color: cb.primaryText),
                      const SizedBox(width: CbSpace.s3),
                      Expanded(
                        child: Text(
                          visitTypeLabel(l10n, value.type),
                          style: text.bodySm.copyWith(color: cb.inkMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CbSpace.s2),
                  Text(
                    visitWhenLabel(context, value.date, value.time, today),
                    style: text.subtitle,
                  ),
                  CbDetailRow(
                    label: l10n.visitPetsLabel,
                    value: [
                      for (final id in value.petIds) pets[id]?.name ?? '…',
                    ].join(', '),
                  ),
                  if (location != null)
                    CbDetailRow(
                      label: l10n.visitLocationLabel,
                      value: location,
                    ),
                  CbDetailRow(
                    label: l10n.visitRemindersLabel,
                    value: value.remindMinutesBefore.isEmpty
                        ? l10n.visitRemindersNone
                        : [
                            for (final minutes in value.remindMinutesBefore)
                              visitReminderLabel(l10n, minutes),
                          ].join(', '),
                  ),
                  if (notes != null)
                    CbDetailRow(label: l10n.careNotesLabel, value: notes),
                ],
              ),
            ),
            if (value.status == VisitStatus.done) ...[
              const SizedBox(height: CbSpace.s6),
              CbSection(
                title: l10n.visitResultTitle,
                child: CbCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      if (value.recordIds.isEmpty)
                        ListTile(title: Text(l10n.visitNoRecords)),
                      if (value.recordIds.isNotEmpty)
                        for (final id in value.petIds)
                          if (pets[id] case final pet?)
                            ListTile(
                              leading: const Icon(Symbols.history_rounded),
                              title: Text(pet.name),
                              subtitle: Text(l10n.visitRecordsOfPet),
                              trailing: const Icon(
                                Symbols.chevron_right_rounded,
                              ),
                              onTap: () => context.push(
                                AppRoutes.pet(pet.id, tab: PetTab.health),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    Visit visit,
    VisitStatus status,
  ) async {
    final l10n = context.l10n;
    if (status == VisitStatus.cancelled) {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.visitCancelTitle,
        message: l10n.visitCancelBody,
        confirmLabel: l10n.visitCancel,
      );
      if (!confirmed || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final visits = ref.read(visitsRepositoryProvider);
    try {
      // The visit as the server has it now: another phone may have changed
      // it since this page loaded, and the whole visit is sent back.
      final fresh = await visits.getVisit(visit.id);
      await visits.updateVisit(
        fresh.id,
        VisitInput(
          type: fresh.type,
          title: fresh.title,
          date: fresh.date,
          time: fresh.time,
          petIds: fresh.petIds,
          remindMinutesBefore: fresh.remindMinutesBefore,
          durationMinutes: fresh.durationMinutes,
          location: fresh.location,
          notes: fresh.notes,
          status: status,
        ),
      );
    } catch (error) {
      debugPrint('Changing the visit failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    } finally {
      refreshVisits(container, visitId: visit.id);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Visit visit) async {
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.visitDeleteTitle,
      message: l10n.visitDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final visits = ref.read(visitsRepositoryProvider);
    try {
      await visits.deleteVisit(visit.id);
      refreshVisits(container);
      if (context.mounted) navigator.pop();
    } catch (error) {
      debugPrint('Deleting the visit failed: $error');
      refreshVisits(container, visitId: visit.id);
      if (isNotFound(error)) {
        if (context.mounted) navigator.pop();
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    }
  }
}

enum _VisitAction { cancel, planAgain, delete }
