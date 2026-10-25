import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../files/open_pdf.dart';
import '../files/page_viewer_screen.dart';
import '../files/stored_file.dart';
import '../files/widgets/page_grid.dart';
import '../household/current_household.dart';
import 'care.dart';
import 'care_labels.dart';
import 'care_refresh.dart';
import 'care_repository.dart';

/// One record: its photos (in the full-screen viewer) and every filled-in
/// detail, with Edit and Delete.
class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({
    super.key,
    required this.petId,
    required this.recordId,
  });

  final String petId;
  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cb = context.cb;
    final record = ref.watch(careRecordProvider(recordId));
    final value = record.value;
    if (value == null) {
      return Scaffold(
        appBar: AppBar(),
        body: record.hasError
            ? Center(
                child: CbErrorState(
                  message: errorMessageFor(record.error!, l10n),
                  traceId: traceIdOf(record.error!),
                  onRetry: () => ref.invalidate(careRecordProvider(recordId)),
                ),
              )
            : const CbLoadingState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(value.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (ref.watch(householdPermissionsProvider).canEdit) ...[
            // A record with values this app doesn't know can't be edited:
            // saving would replace them.
            if (!value.hasUnknownValues)
              IconButton(
                tooltip: l10n.commonEdit,
                icon: const Icon(Symbols.edit_rounded),
                onPressed: () =>
                    context.push(AppRoutes.editCareRecord(petId, recordId)),
              ),
            PopupMenuButton<_RecordAction>(
              tooltip: l10n.commonMoreActions,
              // ⋮ in Material Symbols, as every other icon.
              icon: const Icon(Symbols.more_vert_rounded),
              onSelected: (action) => switch (action) {
                _RecordAction.delete => _delete(context, ref, value),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _RecordAction.delete,
                  child: Row(
                    children: [
                      Icon(Symbols.delete_rounded, color: cb.danger),
                      const SizedBox(width: CbSpace.s3),
                      Text(
                        l10n.recordDelete,
                        style: TextStyle(color: cb.danger),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        // Pull to refresh: another phone may have changed the record.
        onRefresh: () async {
          try {
            ref.invalidate(careRecordProvider(recordId));
            await ref.read(careRecordProvider(recordId).future);
          } catch (error) {
            // The screen keeps what it shows: the snackbar says why.
            if (context.mounted) showRefreshFailed(context, error);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            CbSpace.s4,
            CbSpace.s4,
            CbSpace.s4,
            CbSpace.s12,
          ),
          children: [
            if (value.hasUnknownValues) ...[
              CbNotice(message: l10n.recordReadOnly),
              const SizedBox(height: CbSpace.s6),
            ],
            if (value.files.isNotEmpty) ...[
              CbSection(
                title: l10n.carePhotosTitle,
                child: PageGrid(
                  pages: value.files,
                  onTap: (file) => _openFile(context, ref, value.files, file),
                ),
              ),
              const SizedBox(height: CbSpace.s6),
            ],
            CbSection(
              title: l10n.recordDetailsTitle,
              child: CbCard(child: _RecordDetails(record: value)),
            ),
          ],
        ),
      ),
    );
  }

  /// Photos open in the viewer; a PDF (added on the web, say) opens in the
  /// phone's PDF viewer.
  void _openFile(
    BuildContext context,
    WidgetRef ref,
    List<StoredFile> files,
    StoredFile file,
  ) {
    if (file.isPdf) {
      openPdf(context, ref, file);
      return;
    }
    final photos = [
      for (final f in files)
        if (!f.isPdf) f,
    ];
    openPageViewer(context, pages: photos, initialIndex: photos.indexOf(file));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CareRecord record,
  ) async {
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.recordDeleteTitle,
      message: l10n.recordDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !context.mounted) return;

    // Read before the request: the screen may be gone when it returns, and
    // its ref with it.
    final container = ProviderScope.containerOf(context, listen: false);
    final care = ref.read(careRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await care.deleteRecord(record.id);
    } catch (error) {
      debugPrint('Deleting the record failed: $error');
      // Deleted already, e.g. on another device: that is what the user
      // wants.
      if (!isNotFound(error)) {
        messenger.showSnackBar(
          SnackBar(content: Text(errorMessageFor(error, l10n))),
        );
        return;
      }
    }
    // The plan's "last done" may change with it.
    refreshCare(container, petId, planId: record.planId);
    if (context.mounted) navigator.pop();
  }
}

enum _RecordAction { delete }

/// Every filled-in detail, one per row.
class _RecordDetails extends StatelessWidget {
  const _RecordDetails({required this.record});

  final CareRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final details = record.details;
    final validFrom = record.validFrom;
    final validUntil = record.validUntil;
    final weight = record.weightKg;
    final titer = details.titerIuPerMl;
    String? text(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    final rows = <(String, String?, bool)>[
      (l10n.careKindLabel, careKindLabel(l10n, record.kind), false),
      (l10n.recordPerformedOnLabel, recordDateLabel(context, record), false),
      (
        l10n.careTargetsLabel,
        record.targets.isEmpty
            ? null
            : [
                for (final target in record.targets)
                  vaccineTargetLabel(l10n, target),
              ].join(', '),
        false,
      ),
      (l10n.careProductLabel, text(record.product), false),
      (l10n.careManufacturerLabel, text(record.manufacturer), false),
      (l10n.careBatchLabel, text(record.batchNumber), true),
      (
        l10n.careValidFromLabel,
        validFrom == null ? null : l10n.dateMedium(validFrom),
        false,
      ),
      (
        l10n.careValidUntilLabel,
        validUntil == null ? null : l10n.dateMedium(validUntil),
        false,
      ),
      (l10n.recordLaboratoryLabel, text(details.laboratory), false),
      (l10n.recordReportNumberLabel, text(details.reportNumber), true),
      (
        l10n.recordTiterLabel,
        titer == null
            ? null
            : l10n.recordTiterValue(formatDecimal(l10n, titer)),
        false,
      ),
      (
        l10n.recordWeightLabel,
        weight == null
            ? null
            : l10n.recordWeightValue(formatDecimal(l10n, weight)),
        false,
      ),
      (
        l10n.recordFitForTravel,
        switch (details.fitForTravel) {
          true => l10n.commonYes,
          false => l10n.commonNo,
          null => null,
        },
        false,
      ),
      (l10n.careClinicLabel, text(record.clinic), false),
      (l10n.careVetLabel, text(record.veterinarian), false),
      (l10n.careNotesLabel, text(record.notes), false),
      (
        l10n.recordSourceLabel,
        switch (record.source) {
          RecordSource.manual => l10n.recordSourceManual,
          RecordSource.aiScan => l10n.recordSourceScan,
          null => null,
        },
        false,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value, monospace) in rows)
          if (value != null)
            CbDetailRow(label: label, value: value, monospace: monospace),
      ],
    );
  }
}
