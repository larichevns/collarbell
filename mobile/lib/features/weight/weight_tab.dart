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
import '../care/care_labels.dart' show keepTogether;
import '../household/current_household.dart';
import '../pets/pet.dart';
import 'weighing_sheet.dart';
import 'weight.dart';
import 'weight_labels.dart';
import 'weight_repository.dart';
import 'widgets/weight_chart.dart';

/// The Weight tab of a pet: the latest weight with its change, the weight
/// over time on a chart, and every weight, newest first. The household
/// weighs the pet at home; the weights a vet noted at check-ups join in
/// from the care records.
class WeightTab extends ConsumerStatefulWidget {
  const WeightTab({super.key, required this.pet});

  final Pet pet;

  @override
  ConsumerState<WeightTab> createState() => _WeightTabState();
}

class _WeightTabState extends ConsumerState<WeightTab> {
  /// The period the user chose for the chart; null until they choose one.
  WeightPeriod? _period;

  Pet get _pet => widget.pet;

  void _add() => showWeighingSheet(context, pet: _pet);

  /// What a tap on [entry] opens: a weighing's sheet (not for helpers), or
  /// the check-up record a vet's weight is in. A source this app doesn't
  /// know opens nothing.
  VoidCallback? _onTap(WeightEntry entry, {required bool canEdit}) =>
      switch (entry.source) {
        WeightSource.weighing when canEdit => () => showWeighingSheet(
          context,
          pet: _pet,
          weighing: entry,
        ),
        WeightSource.careRecord => () => context.push(
          AppRoutes.careRecord(_pet.id, entry.id),
        ),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final log = ref.watch(weightLogProvider(_pet.id));
    // Helpers see the weights; adding and changing them is for the others.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    final value = log.value;
    final today = CbDateField.today();
    final add = canEdit
        ? OutlinedButton.icon(
            key: const ValueKey('addWeight'),
            onPressed: _add,
            icon: const Icon(Symbols.add_rounded),
            label: Text(l10n.weightAdd),
          )
        : null;

    final List<Widget> children;
    // A failed reload shows the error, not the old log: a weighing just
    // added would be missing from it.
    if (log.hasError && !log.isLoading) {
      children = [
        CbSection(
          title: l10n.weightLatestTitle,
          action: add,
          child: CbErrorState(
            message: errorMessageFor(log.error!, l10n),
            traceId: traceIdOf(log.error!),
            onRetry: () => ref.invalidate(weightLogProvider(_pet.id)),
          ),
        ),
      ];
    } else if (value == null) {
      children = [
        CbSection(
          title: l10n.weightLatestTitle,
          action: add,
          child: const CbLoadingState(),
        ),
      ];
    } else if (value.isEmpty) {
      children = [_EmptyLog(onAdd: canEdit ? _add : null)];
    } else {
      children = [
        CbSection(
          title: l10n.weightLatestTitle,
          action: add,
          child: _Latest(log: value, today: today),
        ),
        const SizedBox(height: CbSpace.s8),
        CbSection(
          title: l10n.weightTrendTitle,
          child: _trend(context, value, today),
        ),
        const SizedBox(height: CbSpace.s8),
        CbSection(
          title: l10n.weightHistoryTitle,
          child: CbCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < value.length; i++) ...[
                  if (i > 0) const Divider(indent: _rowIndent),
                  _WeightRow(
                    key: ValueKey('${value[i].source.name}-${value[i].id}'),
                    entry: value[i],
                    change: changeAt(value, i),
                    onTap: _onTap(value[i], canEdit: canEdit),
                  ),
                ],
              ],
            ),
          ),
        ),
      ];
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(weightLogProvider(_pet.id));
        try {
          await ref.read(weightLogProvider(_pet.id).future);
        } catch (_) {
          // The error is shown by the error state.
        }
      },
      child: ListView(
        // Pull to refresh works on an empty log too.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          CbSpace.s4,
          CbSpace.s4,
          CbSpace.s12,
        ),
        children: children,
      ),
    );
  }

  /// The chart of the chosen period, with the periods to choose from when
  /// the log is longer than three months.
  Widget _trend(BuildContext context, List<WeightEntry> log, DateTime today) {
    final l10n = context.l10n;
    final periods = weightPeriodsFor(log.last.measuredOn, today);
    final period = periods.contains(_period)
        ? _period!
        : defaultWeightPeriod(periods, log, today);
    final shown = weightsIn(log, period, today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (periods.isNotEmpty) ...[
          Wrap(
            spacing: CbSpace.s2,
            runSpacing: CbSpace.s2,
            children: [
              for (final option in periods)
                ChoiceChip(
                  key: ValueKey(option),
                  label: Text(weightPeriodLabel(l10n, option)),
                  selected: option == period,
                  onSelected: (_) => setState(() => _period = option),
                ),
            ],
          ),
          const SizedBox(height: CbSpace.s3),
        ],
        if (shown.length >= 2)
          CbCard(
            child: WeightChart(points: shown.reversed.toList(), today: today),
          )
        else
          Text(
            log.length < 2 ? l10n.weightChartNeedsTwo : l10n.weightChartTooFew,
            style: context.cbText.body.copyWith(color: context.cb.inkMuted),
          ),
      ],
    );
  }
}

/// Dividers start under the text, not under the source's icon.
const _rowIndent = CbSpace.s4 + CbSize.avatarMd + CbSpace.s3;

/// The latest weight, large, with its date, the change since the weight
/// before it, and its body condition score.
class _Latest extends StatelessWidget {
  const _Latest({required this.log, required this.today});

  /// Newest first; not empty.
  final List<WeightEntry> log;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final latest = log.first;
    final change = changeAt(log, 0);
    final score = latest.bodyCondition;
    return CbCard(
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The unit smaller than the number: the number is what is read.
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: weightNumberLabel(l10n, latest.weightKg),
                    style: text.displayXl,
                  ),
                  TextSpan(text: ' ${l10n.weightUnitKg}', style: text.title),
                ],
              ),
            ),
            const SizedBox(height: CbSpace.s1),
            Text(
              [
                l10n.dateMedium(latest.measuredOn),
                if (latest.isVet) l10n.weightSourceVet,
              ].join(' · '),
              style: text.bodySm.copyWith(color: cb.inkMuted),
            ),
            if (change != null) ...[
              const SizedBox(height: CbSpace.s3),
              Row(
                children: [
                  // Up or down isn't good or bad by itself (a kitten should
                  // gain): the arrow is grey.
                  Icon(
                    change > 0
                        ? Symbols.trending_up_rounded
                        : change < 0
                        ? Symbols.trending_down_rounded
                        : Symbols.trending_flat_rounded,
                    size: 20,
                    color: cb.inkMuted,
                  ),
                  const SizedBox(width: CbSpace.s2),
                  Expanded(
                    child: Text(
                      _changeSince(l10n, change, log[1].measuredOn),
                      style: text.body,
                    ),
                  ),
                ],
              ),
            ],
            if (score != null) ...[
              const SizedBox(height: CbSpace.s2),
              Text(
                [
                  bodyConditionLabel(l10n, score),
                  if (score.isKnown)
                    l10n.weightBcsIdeal(bodyConditionIdeal(score.scale)),
                ].join(' · '),
                style: text.body,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "+0.2 kg since Sep 12", or "No change since Sep 12".
  String _changeSince(AppLocalizations l10n, int grams, DateTime since) {
    final date = weightShortDate(l10n, since, today);
    return grams == 0
        ? l10n.weightNoChangeSince(date)
        : l10n.weightChangeSince(weightChangeLabel(l10n, grams), date);
  }
}

/// One weight of the history: the icon of its source, the weight, then the
/// date, the change from the weight before it and the body condition score,
/// and the note (a vet's weight: its record's title).
class _WeightRow extends StatelessWidget {
  const _WeightRow({
    super.key,
    required this.entry,
    required this.change,
    this.onTap,
  });

  final WeightEntry entry;

  /// From the weight before it, in grams; null for the oldest.
  final int? change;

  /// Opens the weighing's sheet or the vet's record; null shows it only.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final change = this.change;
    final score = entry.bodyCondition;
    final note = entry.note?.trim() ?? '';
    // Short values never break inside; the line wraps between them.
    final details = [
      keepTogether(l10n.dateMedium(entry.measuredOn)),
      if (change != null) keepTogether(weightChangeLabel(l10n, change)),
      if (score != null) keepTogether(bodyConditionLabel(l10n, score)),
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
              _SourceIcon(source: entry.source),
              const SizedBox(width: CbSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weightValueLabel(l10n, entry.weightKg),
                      style: text.subtitle,
                    ),
                    Text(
                      details.join(' · '),
                      style: text.bodySm.copyWith(color: cb.inkMuted),
                    ),
                    if (note.isNotEmpty)
                      Text(
                        note,
                        style: text.bodySm,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Symbols.chevron_right_rounded, color: cb.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a weight comes from, as an icon on a grey disc: a scale for a
/// weighing, the check-up's icon for a vet's weight. Screen readers hear
/// which it is.
class _SourceIcon extends StatelessWidget {
  const _SourceIcon({required this.source});

  final WeightSource source;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Container(
      width: CbSize.avatarMd,
      height: CbSize.avatarMd,
      decoration: BoxDecoration(color: cb.sunken, shape: BoxShape.circle),
      child: Icon(
        weightSourceIcon(source),
        color: cb.inkMuted,
        size: 22,
        semanticLabel: weightSourceLabel(context.l10n, source),
      ),
    );
  }
}

/// No weights yet: why and how often to weigh, and for those who can add
/// one ([onAdd]), the button to start.
class _EmptyLog extends StatelessWidget {
  const _EmptyLog({required this.onAdd});

  /// Null for helpers.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onAdd = this.onAdd;
    return Column(
      children: [
        CbEmptyState(
          icon: Symbols.monitor_weight_rounded,
          title: l10n.weightEmptyTitle,
          message: onAdd == null
              ? l10n.weightEmptyBodyHelper
              : l10n.weightEmptyBody,
        ),
        if (onAdd != null)
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Symbols.add_rounded),
            label: Text(l10n.weightAddFirst),
          ),
      ],
    );
  }
}
