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
import '../care/care.dart';
import '../care/care_labels.dart';
import '../care/care_repository.dart';
import '../household/current_household.dart';
import '../pets/pet.dart';

/// One health section of the EU passport.
enum PassportSection {
  rabies,
  rabiesTiters,
  echinococcus,
  treatments,
  otherVaccinations,
  examinations,
}

/// The health sections V–X of the passport, built by the server from the
/// care records, oldest first as in the paper passport. Each section can
/// add a record from the paper passport, already of the section's kind.
class PassportHealthSections extends ConsumerWidget {
  const PassportHealthSections({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final records = ref.watch(passportRecordsProvider(pet.id));
    final value = records.value;
    // A failed reload shows the error, not old sections: a record added
    // just before would be missing, and the user might add it again.
    if (records.hasError && !records.isLoading) {
      return CbErrorState(
        message: errorMessageFor(records.error!, l10n),
        traceId: traceIdOf(records.error!),
        onRetry: () => ref.invalidate(passportRecordsProvider(pet.id)),
      );
    }
    if (value == null) {
      return const CbLoadingState();
    }
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in PassportSection.values) ...[
          _Section(
            key: ValueKey(section),
            section: section,
            records: switch (section) {
              PassportSection.rabies => value.rabies,
              PassportSection.rabiesTiters => value.rabiesTiters,
              PassportSection.echinococcus => value.echinococcus,
              PassportSection.treatments => value.treatments,
              PassportSection.otherVaccinations => value.otherVaccinations,
              PassportSection.examinations => value.examinations,
            },
            petId: pet.id,
            canAdd: canEdit,
          ),
          const SizedBox(height: CbSpace.s6),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.section,
    required this.records,
    required this.petId,
    required this.canAdd,
  });

  final PassportSection section;
  final List<CareRecord> records;
  final String petId;

  /// "Add": not for helpers.
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (section) {
      PassportSection.rabies => l10n.passportSectionRabies,
      PassportSection.rabiesTiters => l10n.passportSectionTiter,
      PassportSection.echinococcus => l10n.passportSectionEchinococcus,
      PassportSection.treatments => l10n.passportSectionTreatments,
      PassportSection.otherVaccinations =>
        l10n.passportSectionOtherVaccinations,
      PassportSection.examinations => l10n.passportSectionExaminations,
    };
    // "Add" opens the record form with the section's kind: a rabies
    // vaccination, a deworming for the treatments...
    final newRecord = switch (section) {
      PassportSection.rabies => AppRoutes.newCareRecord(
        petId,
        kind: CareKind.vaccination,
        target: VaccineTarget.rabies,
      ),
      PassportSection.rabiesTiters => AppRoutes.newCareRecord(
        petId,
        kind: CareKind.rabiesTiter,
      ),
      PassportSection.echinococcus => AppRoutes.newCareRecord(
        petId,
        kind: CareKind.echinococcus,
      ),
      PassportSection.treatments => AppRoutes.newCareRecord(
        petId,
        kind: CareKind.deworming,
      ),
      PassportSection.otherVaccinations => AppRoutes.newCareRecord(
        petId,
        kind: CareKind.vaccination,
      ),
      PassportSection.examinations => AppRoutes.newCareRecord(
        petId,
        kind: CareKind.vetExam,
      ),
    };

    return CbSection(
      title: title,
      // The titles are long ("VIII. Other parasite treatments"): a round
      // "+" keeps beside them, its word in the tooltip, and a title too
      // long wraps.
      titleWraps: true,
      action: canAdd
          ? IconButton.outlined(
              style: cbOutlinedIconButtonStyle(context),
              tooltip: l10n.commonAdd,
              onPressed: () => context.push(newRecord),
              icon: const Icon(Symbols.add_rounded),
            )
          : null,
      child: CbCard(
        padding: records.isEmpty
            ? const EdgeInsets.all(CbSpace.s4)
            : EdgeInsets.zero,
        child: records.isEmpty
            ? Text(
                l10n.passportSectionEmpty,
                style: context.cbText.body.copyWith(color: context.cb.inkMuted),
              )
            : Column(
                children: [
                  for (var i = 0; i < records.length; i++) ...[
                    if (i > 0) const Divider(indent: CbSpace.s4),
                    _PassportRow(
                      key: ValueKey(records[i].id),
                      section: section,
                      record: records[i],
                      onTap: () => context.push(
                        AppRoutes.careRecord(petId, records[i].id),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// A compact row, like a line of the paper passport: the date (with the
/// time for the tapeworm treatment), what was given and the details that
/// matter for the section.
class _PassportRow extends StatelessWidget {
  const _PassportRow({
    super.key,
    required this.section,
    required this.record,
    required this.onTap,
  });

  final PassportSection section;
  final CareRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final product = record.product;
    final batch = record.batchNumber;
    final validFrom = record.validFrom;
    final validUntil = record.validUntil;
    final titer = record.details.titerIuPerMl;
    final laboratory = record.details.laboratory;

    // What was given: the product, else the title. Treatments say their
    // kind too, since the section mixes worms, fleas and heartworm, unless
    // the name says it already.
    final name = product ?? record.title;
    final kind = careKindLabel(l10n, record.kind);
    final what = [
      if (section == PassportSection.treatments && kind != name) kind,
      name,
      if (batch != null) l10n.careBatchValue(batch),
    ];
    final more = [
      if (validFrom != null && validUntil != null)
        l10n.careValidRange(validFrom, validUntil)
      else if (validUntil != null)
        l10n.careValidUntilValue(validUntil)
      else if (validFrom != null)
        l10n.careValidFromValue(validFrom),
      if (titer != null) l10n.recordTiterValue(formatDecimal(l10n, titer)),
      ?laboratory,
      if (record.details.fitForTravel == true) l10n.recordFitForTravel,
      if (record.details.fitForTravel == false) l10n.recordNotFitForTravel,
      if (section == PassportSection.examinations) ?record.clinic,
    ];

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CbSpace.s4,
            vertical: CbSpace.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recordDateLabel(context, record), style: text.label),
                    const SizedBox(height: CbSpace.s1),
                    Text(what.join(' · '), style: text.body),
                    if (more.isNotEmpty)
                      Text(
                        more.join(' · '),
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                      ),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right_rounded, color: cb.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
