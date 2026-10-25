import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/cb_card.dart';
import '../../../shared/widgets/cb_status_tag.dart';
import '../../../theme/collarbell_theme.dart';
import '../../care/care.dart';
import '../../care/care_labels.dart';
import '../../care/care_rules.dart';
import '../../care/widgets/kind_icon.dart';
import '../../pets/identifier_rules.dart';
import '../../pets/pet.dart';
import '../../pets/pet_labels.dart';
import '../../weight/weight_labels.dart';
import '../ai.dart';
import '../ai_labels.dart';
import '../scan_review.dart';

// The entries of a scan on the review screen: a card per record, weight,
// microchip or tattoo, and for the passport details. Each card is a form
// field, so a save checks every ticked entry and scrolls to the first one
// with a problem. The cards change their entry only through [ReviewUpdate],
// which rebuilds the review. A card of a note (`fromNote`) shows the note's
// words its entry was read from, and its doubts speak of the note, not of a
// paper.

/// Applies a change to an entry of the review and rebuilds the review.
typedef ReviewUpdate = void Function(VoidCallback change);

/// Where the tick and the texts of a card start: the values line up under
/// the title, past the checkbox.
const _indent = CbSize.check + CbSpace.s1;

/// One record of the draft: the tick, kind and title, the values with the
/// AI's doubts, where it was read, and the plan it is a "Done" of.
class RecordDraftCard extends StatelessWidget {
  const RecordDraftCard({
    super.key,
    required this.entry,
    required this.plans,
    required this.problems,
    required this.showProblems,
    required this.update,
    required this.onEdit,
    required this.onEnterDate,
    required this.onChoosePlan,
    this.onOpenPage,
    this.fromNote = false,
  });

  final ReviewRecord entry;

  /// The pet's plans: a record can be a "Done" of one of its kind.
  final List<CarePlan> plans;

  /// What keeps the entry from being saved, worked out when asked.
  final Map<String, String> Function() problems;

  /// A save was tried: the problems show on the card.
  final bool showProblems;
  final ReviewUpdate update;
  final VoidCallback onEdit;

  /// Asks for the date the AI couldn't read.
  final VoidCallback onEnterDate;

  /// Asks which plan the record is a "Done" of.
  final VoidCallback onChoosePlan;

  /// Opens the photo the entry was read from; null when it is gone.
  final VoidCallback? onOpenPage;

  /// Read from a note, not from photos.
  final bool fromNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = this.entry;
    final performedOn = entry.performedOn;
    final time = entry.performedTime;
    final warnings = entry.fieldWarnings;
    List<DraftWarning> about(String field) => [
      for (final warning in warnings)
        if (warning.field == field) warning,
    ];
    final product = [?entry.product, ?entry.manufacturer].join(', ');
    final weight = entry.weightKg;
    final kind = careKindLabel(l10n, entry.kind);
    final title = entry.titleOr(
      (kind, targets) => scanDefaultTitle(l10n, kind, targets),
    );

    return _EntryField(
      selected: entry.selected,
      problems: problems,
      builder: (context) => _EntryCard(
        selected: entry.selected,
        onSelected: entry.canSelect
            ? (selected) => update(() => entry.selected = selected)
            : null,
        leading: KindIcon(kind: entry.kind),
        title: title,
        // A title that is the kind's name says it already.
        subtitle: title == kind ? null : kind,
        onEdit: onEdit,
        children: [
          _Badges(issues: entry.draft.warnings, fromNote: fromNote),
          if (!entry.canSelect) _Hint(l10n.scanNeedsDate),
          _ValueRow(
            label: l10n.recordPerformedOnLabel,
            value: performedOn == null
                ? null
                : time == null
                ? l10n.dateMedium(performedOn)
                : l10n.dateWithTime(performedOn, time.format(context)),
            fromNote: fromNote,
            warnings: [...about('performedOn'), ...about('performedTime')],
            actions: [
              if (performedOn == null)
                TextButton(
                  onPressed: onEnterDate,
                  child: Text(l10n.scanEnterDate),
                )
              else
                ?_swapButton(
                  context,
                  warnings: warnings,
                  field: 'performedOn',
                  date: performedOn,
                  onSwap: (date) => entry.setDate('performedOn', date),
                ),
            ],
          ),
          if (usesTargets(entry.kind) && entry.targets.isNotEmpty)
            _ValueRow(
              label: l10n.careTargetsLabel,
              value: [
                for (final target in entry.targets)
                  vaccineTargetLabel(l10n, target),
              ].join(', '),
            ),
          if (product.isNotEmpty)
            _ValueRow(label: l10n.careProductLabel, value: product),
          if (entry.batchNumber != null)
            _ValueRow(
              label: l10n.careBatchLabel,
              value: entry.batchNumber,
              monospace: true,
            ),
          for (final (field, label, value) in [
            ('validFrom', l10n.careValidFromLabel, entry.validFrom),
            ('validUntil', l10n.careValidUntilLabel, entry.validUntil),
          ])
            if (value != null || about(field).isNotEmpty)
              _ValueRow(
                label: label,
                value: value == null ? null : l10n.dateMedium(value),
                fromNote: fromNote,
                warnings: about(field),
                actions: [
                  if (value != null)
                    ?_swapButton(
                      context,
                      warnings: warnings,
                      field: field,
                      date: value,
                      onSwap: (date) => entry.setDate(field, date),
                    ),
                ],
              ),
          // Only a check-up keeps a weight: another kind saves none.
          if (usesExam(entry.kind) &&
              (weight != null || about('weightKg').isNotEmpty))
            _ValueRow(
              label: l10n.weightLabel,
              value: weight == null ? null : weightValueLabel(l10n, weight),
              fromNote: fromNote,
              warnings: about('weightKg'),
            ),
          if (entry.veterinarian != null)
            _ValueRow(label: l10n.careVetLabel, value: entry.veterinarian),
          if (entry.clinic != null)
            _ValueRow(label: l10n.careClinicLabel, value: entry.clinic),
          DraftEvidence(
            page: entry.draft.page,
            evidence: entry.draft.evidence,
            onOpen: onOpenPage,
            fromNote: fromNote,
          ),
          _PlanLink(
            entry: entry,
            plans: plans,
            update: update,
            onChoosePlan: onChoosePlan,
          ),
          if (showProblems && entry.selected)
            _Problems(problems: problems(), label: _recordFieldLabel),
        ],
      ),
    );
  }

  Widget? _swapButton(
    BuildContext context, {
    required List<DraftWarning> warnings,
    required String field,
    required DateTime date,
    required ValueChanged<DateTime> onSwap,
  }) => swapDateButton(
    context,
    warnings: warnings,
    field: field,
    date: date,
    update: update,
    onSwap: onSwap,
  );

  static String? _recordFieldLabel(AppLocalizations l10n, String field) =>
      switch (field) {
        'kind' => l10n.careKindLabel,
        'title' => l10n.recordTitleLabel,
        'performedOn' => l10n.recordPerformedOnLabel,
        'performedTime' => l10n.careTimeLabel,
        'targets' => l10n.careTargetsLabel,
        'product' => l10n.careProductLabel,
        'manufacturer' => l10n.careManufacturerLabel,
        'batchNumber' => l10n.careBatchLabel,
        'validFrom' => l10n.careValidFromLabel,
        'validUntil' => l10n.careValidUntilLabel,
        'clinic' => l10n.careClinicLabel,
        'veterinarian' => l10n.careVetLabel,
        'weightKg' => l10n.weightLabel,
        'planId' => l10n.healthPlansTitle,
        _ => null,
      };
}

/// One microchip or tattoo of the draft.
class IdentifierDraftCard extends StatelessWidget {
  const IdentifierDraftCard({
    super.key,
    required this.entry,
    required this.problems,
    required this.showProblems,
    required this.update,
    required this.onEdit,
    this.onOpenPage,
    this.fromNote = false,
  });

  final ReviewIdentifier entry;
  final Map<String, String> Function() problems;
  final bool showProblems;
  final ReviewUpdate update;
  final VoidCallback onEdit;
  final VoidCallback? onOpenPage;

  /// Read from a note, not from photos.
  final bool fromNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final entry = this.entry;
    final tattoo = entry.type == IdentifierType.tattoo;
    final appliedOn = entry.appliedOn;
    final location = entry.location;
    final code = IdentifierRules.normalize(entry.code);
    final warnings = entry.fieldWarnings;
    List<DraftWarning> about(String field) => [
      for (final warning in warnings)
        if (warning.field == field) warning,
    ];
    final details = [
      if (appliedOn != null)
        tattoo
            ? l10n.identifierTattooAppliedOn(appliedOn)
            : l10n.identifierChipImplantedOn(appliedOn),
      ?location,
    ];

    return _EntryField(
      selected: entry.selected,
      problems: problems,
      builder: (context) => _EntryCard(
        selected: entry.selected,
        onSelected: entry.canSelect
            ? (selected) => update(() => entry.selected = selected)
            : null,
        title: code.isEmpty
            ? l10n.scanNotRead
            : IdentifierRules.display(entry.type, code),
        titleStyle: code.isEmpty ? null : text.code,
        overline: identifierTypeLabel(l10n, entry.type),
        onEdit: onEdit,
        children: [
          _Badges(
            issues: entry.draft.warnings,
            identifier: true,
            fromNote: fromNote,
          ),
          if (!entry.canSelect) _Hint(l10n.scanNeedsCode),
          for (final warning in about('code'))
            _Warning(warning, fromNote: fromNote),
          if (details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: CbSpace.s1),
              child: Text(
                details.join(' · '),
                style: text.bodySm.copyWith(color: cb.inkMuted),
              ),
            ),
          for (final warning in [...about('appliedOn'), ...about('location')])
            _Warning(warning, fromNote: fromNote),
          if (appliedOn != null)
            ?swapDateButton(
              context,
              warnings: warnings,
              field: 'appliedOn',
              date: appliedOn,
              update: update,
              onSwap: entry.setAppliedOn,
            ),
          DraftEvidence(
            page: entry.draft.page,
            evidence: entry.draft.evidence,
            onOpen: onOpenPage,
            fromNote: fromNote,
          ),
          if (showProblems && entry.selected)
            _Problems(
              problems: problems(),
              label: (l10n, field) => switch (field) {
                'type' => l10n.identifierTypeLabel,
                'code' =>
                  tattoo
                      ? l10n.identifierTattooLabel
                      : l10n.identifierChipLabel,
                'appliedOn' =>
                  tattoo
                      ? l10n.identifierTattooDateLabel
                      : l10n.identifierChipDateLabel,
                'location' => l10n.identifierLocationLabel,
                _ => null,
              },
            ),
        ],
      ),
    );
  }
}

/// The passport details of the draft against what is saved: a value for
/// an empty field is added when the card is ticked; a value that differs
/// from the saved one has its own switch to replace it, off until the user
/// turns it on (or changes the value).
class PassportDraftCard extends StatelessWidget {
  const PassportDraftCard({
    super.key,
    required this.entry,
    required this.problems,
    required this.showProblems,
    required this.update,
    required this.onEdit,
    this.onOpenPage,
    this.fromNote = false,
  });

  final ReviewPassport entry;
  final Map<String, String> Function() problems;
  final bool showProblems;
  final ReviewUpdate update;
  final VoidCallback onEdit;
  final VoidCallback? onOpenPage;

  /// Read from a note, not from photos.
  final bool fromNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = this.entry;
    final number = entry.number;
    final country = entry.issuingCountry;
    final issuedOn = entry.issuedOn;
    final savedIssuedOn = entry.saved.issuedOn;
    final warnings = entry.fieldWarnings;
    List<DraftWarning> about(PassportField field) => [
      for (final warning in warnings)
        if (warning.field == field.apiName) warning,
    ];
    final readNothing = PassportField.values.every(
      (field) => entry.valueOf(field) == null,
    );

    // Under a value: the same as saved, or what is saved and the switch
    // to replace it.
    String? note(PassportField field, String? saved) => entry.differs(field)
        ? l10n.scanSavedValue(saved!)
        : entry.valueOf(field) != null && entry.savedValueOf(field) != null
        ? l10n.scanPassportSame
        : null;
    Widget? replaceSwitch(PassportField field) => entry.differs(field)
        ? SwitchListTile(
            key: ValueKey('replace-${field.apiName}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: entry.replace.contains(field),
            title: Text(l10n.scanPassportReplace),
            onChanged: (on) => update(() {
              if (on) {
                entry.replace.add(field);
                // Replacing is the reason to save the card.
                entry.selected = true;
              } else {
                entry.replace.remove(field);
              }
            }),
          )
        : null;

    return _EntryField(
      selected: entry.selected,
      problems: problems,
      builder: (context) => _EntryCard(
        selected: entry.selected,
        onSelected: entry.canSelect
            ? (selected) => update(() => entry.selected = selected)
            : null,
        title: l10n.scanPassportFillIn,
        onEdit: onEdit,
        children: [
          _Badges(issues: entry.draft.warnings, fromNote: fromNote),
          if (!entry.canSelect)
            _Hint(
              readNothing
                  ? l10n.scanNothingToFill
                  : l10n.scanPassportNothingNew,
            )
          else if (entry.selected && entry.changes.isEmpty)
            _Hint(l10n.scanPassportTurnOnReplace),
          if (number != null || about(PassportField.number).isNotEmpty)
            _ValueRow(
              label: l10n.passportNumberLabel,
              value: number,
              monospace: true,
              note: note(PassportField.number, entry.saved.number),
              fromNote: fromNote,
              warnings: about(PassportField.number),
              actions: [?replaceSwitch(PassportField.number)],
            ),
          if (country != null || about(PassportField.country).isNotEmpty)
            _ValueRow(
              label: l10n.passportCountryLabel,
              value: country,
              note: note(PassportField.country, entry.saved.issuingCountry),
              fromNote: fromNote,
              warnings: about(PassportField.country),
              actions: [?replaceSwitch(PassportField.country)],
            ),
          if (issuedOn != null || about(PassportField.issuedOn).isNotEmpty)
            _ValueRow(
              label: l10n.passportIssuedOnLabel,
              value: issuedOn == null ? null : l10n.dateMedium(issuedOn),
              note: note(
                PassportField.issuedOn,
                savedIssuedOn == null ? null : l10n.dateMedium(savedIssuedOn),
              ),
              fromNote: fromNote,
              warnings: about(PassportField.issuedOn),
              actions: [
                if (issuedOn != null)
                  ?swapDateButton(
                    context,
                    warnings: warnings,
                    field: PassportField.issuedOn.apiName,
                    date: issuedOn,
                    update: update,
                    onSwap: entry.setIssuedOn,
                  ),
                ?replaceSwitch(PassportField.issuedOn),
              ],
            ),
          DraftEvidence(
            page: entry.draft.page,
            evidence: entry.draft.evidence,
            onOpen: onOpenPage,
            fromNote: fromNote,
          ),
          if (showProblems && entry.selected)
            _Problems(
              problems: problems(),
              label: (l10n, field) => switch (field) {
                'passportNumber' => l10n.passportNumberLabel,
                'issuingCountry' => l10n.passportCountryLabel,
                'issuedOn' => l10n.passportIssuedOnLabel,
                _ => null,
              },
            ),
        ],
      ),
    );
  }
}

/// One weight of the draft, saved as a weighing of the pet's log: the
/// tick, the weight, its day with the AI's doubts, and where it was read.
class WeightDraftCard extends StatelessWidget {
  const WeightDraftCard({
    super.key,
    required this.entry,
    required this.problems,
    required this.showProblems,
    required this.update,
    required this.onEdit,
    this.onOpenPage,
    this.fromNote = false,
  });

  final ReviewWeight entry;
  final Map<String, String> Function() problems;
  final bool showProblems;
  final ReviewUpdate update;
  final VoidCallback onEdit;
  final VoidCallback? onOpenPage;

  /// Read from a note, not from photos.
  final bool fromNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = this.entry;
    final measuredOn = entry.measuredOn;
    final weight = entry.weightKg;
    final warnings = entry.fieldWarnings;
    List<DraftWarning> about(String field) => [
      for (final warning in warnings)
        if (warning.field == field) warning,
    ];

    return _EntryField(
      selected: entry.selected,
      problems: problems,
      builder: (context) => _EntryCard(
        selected: entry.selected,
        onSelected: entry.canSelect
            ? (selected) => update(() => entry.selected = selected)
            : null,
        leading: const _IconDisc(Symbols.monitor_weight_rounded),
        overline: l10n.weightSourceWeighing,
        title: weight == null
            ? l10n.scanNotRead
            : weightValueLabel(l10n, weight),
        onEdit: onEdit,
        children: [
          _Badges(
            issues: entry.draft.warnings,
            weight: true,
            fromNote: fromNote,
          ),
          if (weight == null)
            _Hint(l10n.scanNeedsWeight)
          else if (measuredOn == null)
            _Hint(l10n.scanNeedsDate),
          for (final warning in about('weightKg'))
            _Warning(warning, fromNote: fromNote),
          _ValueRow(
            label: l10n.weightMeasuredOnLabel,
            value: measuredOn == null ? null : l10n.dateMedium(measuredOn),
            fromNote: fromNote,
            warnings: about('measuredOn'),
            actions: [
              if (measuredOn != null)
                ?swapDateButton(
                  context,
                  warnings: warnings,
                  field: 'measuredOn',
                  date: measuredOn,
                  update: update,
                  onSwap: entry.setMeasuredOn,
                ),
            ],
          ),
          DraftEvidence(
            page: entry.draft.page,
            evidence: entry.draft.evidence,
            onOpen: onOpenPage,
            fromNote: fromNote,
          ),
          if (showProblems && entry.selected)
            _Problems(
              problems: problems(),
              label: (l10n, field) => switch (field) {
                'measuredOn' => l10n.weightMeasuredOnLabel,
                'weightKg' => l10n.weightLabel,
                _ => null,
              },
            ),
        ],
      ),
    );
  }
}

/// An icon on a grey disc at the start of a card, like [KindIcon].
/// Decorative: the card's text says what it is.
class _IconDisc extends StatelessWidget {
  const _IconDisc(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return ExcludeSemantics(
      child: Container(
        width: CbSize.avatarMd,
        height: CbSize.avatarMd,
        decoration: BoxDecoration(color: cb.sunken, shape: BoxShape.circle),
        child: Icon(icon, color: cb.inkMuted, size: 22),
      ),
    );
  }
}

/// "Change to 4 Mar 2025" under a date whose day and month could be the
/// other way round ([field] has the AI's doubt "ambiguous"); null for other
/// dates. [onSwap] sets the swapped date on the entry.
Widget? swapDateButton(
  BuildContext context, {
  required List<DraftWarning> warnings,
  required String field,
  required DateTime date,
  required ReviewUpdate update,
  required ValueChanged<DateTime> onSwap,
}) {
  final ambiguous = warnings.any(
    (w) => w.field == field && w.issue == DraftIssue.ambiguous,
  );
  final swapped = swapDayAndMonth(date);
  if (!ambiguous || swapped == null) return null;
  return Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton(
      key: ValueKey('swap-$field'),
      style: cbInlineTextButtonStyle,
      onPressed: () => update(() => onSwap(swapped)),
      child: Text(context.l10n.scanSwapTo(swapped)),
    ),
  );
}

/// Where an entry was read: "Read on page 2", the text as on the page, and
/// a tap opens that photo. For a note ([fromNote]): "From your note" and its
/// words, or nothing when the AI gave none.
class DraftEvidence extends StatelessWidget {
  const DraftEvidence({
    super.key,
    required this.page,
    required this.evidence,
    required this.onOpen,
    this.fromNote = false,
  });

  /// Counted from 1.
  final int page;
  final String? evidence;

  /// Null when the photo is gone, and for a note.
  final VoidCallback? onOpen;
  final bool fromNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final evidence = this.evidence;
    // A note has no page to point at.
    if (fromNote && evidence == null) return const SizedBox.shrink();
    final onOpen = fromNote ? null : this.onOpen;
    final radius = BorderRadius.circular(CbRadius.sm);
    return Padding(
      padding: const EdgeInsets.only(top: CbSpace.s3),
      child: Semantics(
        button: onOpen != null,
        child: Material(
          color: cb.sunken,
          borderRadius: radius,
          child: InkWell(
            onTap: onOpen,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(CbSpace.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fromNote
                              ? l10n.noteEvidence
                              : l10n.scanReadOnPage(page),
                          style: text.caption.copyWith(color: cb.inkMuted),
                        ),
                        if (evidence != null) ...[
                          const SizedBox(height: CbSpace.s1),
                          Text(l10n.scanEvidence(evidence), style: text.bodySm),
                        ],
                      ],
                    ),
                  ),
                  if (onOpen != null) ...[
                    const SizedBox(width: CbSpace.s2),
                    Icon(Symbols.image_rounded, size: 20, color: cb.inkMuted),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Mark as done in plan “Rabies”": a switch for a record whose kind has
/// plans, and a way to choose another plan or none.
class _PlanLink extends StatelessWidget {
  const _PlanLink({
    required this.entry,
    required this.plans,
    required this.update,
    required this.onChoosePlan,
  });

  final ReviewRecord entry;
  final List<CarePlan> plans;
  final ReviewUpdate update;
  final VoidCallback onChoosePlan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final planId = entry.planId;
    CarePlan? linked;
    for (final plan in plans) {
      if (plan.id == planId) linked = plan;
    }
    final choices = planChoices(entry, plans);
    if (planId == null && choices.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: CbSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            // On while a plan is linked, even one gone since (deleted on
            // another phone): turning it off unlinks it.
            value: planId != null,
            title: Text(
              linked == null
                  ? l10n.scanPlanLink
                  : l10n.scanPlanDone(linked.title),
              style: text.body,
            ),
            subtitle: planId == null
                ? null
                : Text(
                    l10n.scanPlanHint,
                    style: text.bodySm.copyWith(color: cb.inkMuted),
                  ),
            onChanged: (on) {
              if (!on) {
                update(() => entry.setPlan(null));
              } else if (choices.length == 1) {
                update(() => entry.setPlan(choices.single.id));
              } else {
                onChoosePlan();
              }
            },
          ),
          if (planId != null && choices.length > 1)
            TextButton(
              style: cbInlineTextButtonStyle,
              onPressed: onChoosePlan,
              child: Text(l10n.scanPlanChange),
            ),
        ],
      ),
    );
  }
}

/// The plans a record can be a "Done" of, as the server allows: the active
/// plans of its kind (and the one it is linked to), and for a vaccination
/// only plans against the same diseases when both say which.
List<CarePlan> planChoices(ReviewRecord entry, List<CarePlan> plans) => [
  for (final plan in plans)
    if (plan.kind == entry.kind &&
        (plan.active || plan.id == entry.planId) &&
        (entry.kind != CareKind.vaccination ||
            plan.targets.isEmpty ||
            entry.targets.isEmpty ||
            plan.targets.any(entry.targets.contains)))
      plan,
];

/// Makes a card a form field: a ticked entry with problems fails
/// validation, so a save finds it and scrolls to it.
class _EntryField extends StatelessWidget {
  const _EntryField({
    required this.selected,
    required this.problems,
    required this.builder,
  });

  final bool selected;
  final Map<String, String> Function() problems;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return FormField<void>(
      validator: (_) =>
          selected && problems().isNotEmpty ? context.l10n.scanEntryFix : null,
      builder: (field) => builder(context),
    );
  }
}

/// The frame of an entry: the tick, the title, Edit, then the details.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.selected,
    required this.onSelected,
    required this.title,
    required this.onEdit,
    required this.children,
    this.leading,
    this.subtitle,
    this.overline,
    this.titleStyle,
  });

  final bool selected;

  /// Null when the entry can't be ticked yet.
  final ValueChanged<bool>? onSelected;
  final Widget? leading;
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;

  /// A caption above the title, e.g. "ISO microchip".
  final String? overline;
  final VoidCallback onEdit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final onSelected = this.onSelected;
    final leading = this.leading;
    final subtitle = this.subtitle;
    final overline = this.overline;
    return CbCard(
      padding: const EdgeInsets.fromLTRB(
        CbSpace.s1,
        CbSpace.s2,
        CbSpace.s2,
        CbSpace.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: CbSize.check,
                child: Checkbox(
                  value: selected,
                  semanticLabel: l10n.scanSelectEntry,
                  onChanged: onSelected == null
                      ? null
                      : (value) => onSelected(value ?? false),
                ),
              ),
              if (leading != null) ...[
                leading,
                const SizedBox(width: CbSpace.s3),
              ],
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (overline != null)
                        Text(
                          overline,
                          style: text.caption.copyWith(color: cb.inkMuted),
                        ),
                      Text(
                        title,
                        style: titleStyle ?? text.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: text.bodySm.copyWith(color: cb.inkMuted),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.commonEdit,
                icon: const Icon(Symbols.edit_rounded),
                onPressed: onEdit,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: _indent, right: CbSpace.s2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// One value of an entry: its label, the value (or "Not read"), what is
/// saved already when it differs, the AI's doubts and a quick fix.
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    this.monospace = false,
    this.note,
    this.warnings = const [],
    this.fromNote = false,
    this.actions = const [],
  });

  final String label;

  /// Null when the AI couldn't read it.
  final String? value;
  final bool monospace;

  /// E.g. "Saved: DE0123456".
  final String? note;
  final List<DraftWarning> warnings;

  /// The doubts are about a note the user wrote, not a paper.
  final bool fromNote;

  /// Quick fixes and switches under the value.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final value = this.value;
    final note = this.note;
    return Padding(
      padding: const EdgeInsets.only(top: CbSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.caption.copyWith(color: cb.inkMuted)),
                Text(
                  value ?? l10n.scanNotRead,
                  style: value == null
                      ? text.body.copyWith(color: cb.inkMuted)
                      : monospace
                      ? text.code
                      : text.body,
                ),
                if (note != null)
                  Text(note, style: text.bodySm.copyWith(color: cb.inkMuted)),
              ],
            ),
          ),
          for (final warning in warnings) _Warning(warning, fromNote: fromNote),
          // In line with the value above: no indent ([cbInlineTextButtonStyle]).
          for (final action in actions)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButtonTheme(
                data: TextButtonThemeData(
                  style: cbInlineTextButtonStyle.merge(
                    Theme.of(context).textButtonTheme.style,
                  ),
                ),
                child: action,
              ),
            ),
        ],
      ),
    );
  }
}

/// A doubt of the AI about a value: a yellow "check this" status tag.
class _Warning extends StatelessWidget {
  const _Warning(this.warning, {this.fromNote = false});

  final DraftWarning warning;
  final bool fromNote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: CbSpace.s1),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: CbStatusTag.soon(
          draftIssueMessage(context.l10n, warning.issue, fromNote: fromNote),
          icon: Symbols.warning_rounded,
        ),
      ),
    );
  }
}

/// Badges for doubts about the whole entry: "Already saved", "Same as
/// another entry", with what they mean.
class _Badges extends StatelessWidget {
  const _Badges({
    required this.issues,
    this.identifier = false,
    this.weight = false,
    this.fromNote = false,
  });

  final List<DraftWarning> issues;

  /// Words "already saved" for a microchip number.
  final bool identifier;

  /// Words "already saved" and "repeated" for a weight.
  final bool weight;

  /// Words "repeated" for an entry of a note.
  final bool fromNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final seen = <DraftIssue>{};
    final shown = [
      for (final warning in issues)
        if (draftIssueBadge(l10n, warning.issue) != null &&
            seen.add(warning.issue))
          warning.issue,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: CbSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: CbSpace.s1),
              child: MergeSemantics(
                child: Wrap(
                  spacing: CbSpace.s2,
                  runSpacing: CbSpace.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CbStatusTag(
                      label: draftIssueBadge(l10n, issue)!,
                      tone: CbStatusTone.soon,
                    ),
                    if (issue != DraftIssue.differsFromSaved)
                      Text(
                        draftIssueMessage(
                          l10n,
                          issue,
                          identifier: identifier,
                          weight: weight,
                          fromNote: fromNote,
                        ),
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Why an entry can't be ticked yet, e.g. "Enter the date to save this
/// entry."
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: CbSpace.s2),
    child: Text(
      text,
      style: context.cbText.bodySm.copyWith(color: context.cb.inkMuted),
    ),
  );
}

/// What keeps a ticked entry from being saved, after a save was tried:
/// "Date: A date in the future can't be saved".
class _Problems extends StatelessWidget {
  const _Problems({required this.problems, required this.label});

  final Map<String, String> problems;

  /// The field's name on screen; null for problems about the whole entry.
  final String? Function(AppLocalizations l10n, String field) label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final style = context.cbText.bodySm.copyWith(color: cb.danger);
    if (problems.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: CbSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final MapEntry(key: field, value: message) in problems.entries)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Symbols.error_rounded,
                      size: 16,
                      color: cb.danger,
                    ),
                  ),
                  const SizedBox(width: CbSpace.s1),
                  Expanded(
                    child: Text(switch (label(l10n, field)) {
                      final name? => '$name: $message',
                      null => message,
                    }, style: style),
                  ),
                ],
              ),
            Text(l10n.scanEntryFix, style: style),
          ],
        ),
      ),
    );
  }
}
