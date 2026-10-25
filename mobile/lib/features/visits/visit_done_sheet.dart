import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../theme/collarbell_theme.dart';
import '../care/care.dart';
import '../care/care_labels.dart';
import '../care/care_repository.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import 'visit.dart';
import 'visit_refresh.dart';
import 'visits_repository.dart';

/// "The visit took place": asks whether to write it into the pets' care
/// history (an exam after the vet, grooming after the groomer) and which of
/// their plans it completes, e.g. the yearly check-up.
Future<void> showVisitDoneSheet(BuildContext context, Visit visit) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // A swipe down would close it at once and lose the notes: Back and a
      // tap outside ask first instead (LeaveGuard).
      enableDrag: false,
      builder: (context) => _VisitDoneSheet(visit: visit),
    );

class _VisitDoneSheet extends ConsumerStatefulWidget {
  const _VisitDoneSheet({required this.visit});

  final Visit visit;

  @override
  ConsumerState<_VisitDoneSheet> createState() => _VisitDoneSheetState();
}

class _VisitDoneSheetState extends ConsumerState<_VisitDoneSheet> {
  late var _writeRecord = defaultRecordKind(widget.visit.type) != null;
  late var _kind = defaultRecordKind(widget.visit.type) ?? CareKind.vetExam;

  /// Plans the user chose to count the visit as "Done" for, by pet.
  final _plans = <String, String>{};

  /// Pets whose plan choice the user changed; the others follow the
  /// suggestion as the plans load or the kind changes.
  final _touched = <String>{};
  final _notes = TextEditingController();
  var _busy = false;
  String? _failure;

  /// What the sheet opened with: closing loses anything only if it differs.
  late final bool _openedWriteRecord;
  late final CareKind _openedKind;

  @override
  void initState() {
    super.initState();
    _openedWriteRecord = _writeRecord;
    _openedKind = _kind;
  }

  /// Whether closing would lose a choice or the notes. A plan picked by hand
  /// that is the suggestion anyway (unchecked and checked again) is no change.
  bool _changed() =>
      _writeRecord != _openedWriteRecord ||
      _kind != _openedKind ||
      _notes.text.trim().isNotEmpty ||
      _touched.any((petId) => _plans[petId] != _suggested(petId, watch: false));

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// The pet's active plans of the chosen kind. [watch] is false outside
  /// build, e.g. when Back asks whether anything changed.
  List<CarePlan> _matching(String petId, {bool watch = true}) {
    final plans = watch
        ? ref.watch(carePlansProvider(petId))
        : ref.read(carePlansProvider(petId));
    return [
      for (final plan in plans.value ?? const <CarePlan>[])
        if (plan.active && plan.kind == _kind) plan,
    ];
  }

  /// The suggestion: the only matching plan, when it repeats (a one-off
  /// plan, such as a check before a trip, isn't closed by just any visit).
  String? _suggested(String petId, {bool watch = true}) {
    final plans = _matching(petId, watch: watch);
    return plans.length == 1 && plans.single.interval != null
        ? plans.single.id
        : null;
  }

  String? _chosen(String petId) =>
      _touched.contains(petId) ? _plans[petId] : _suggested(petId);

  Future<void> _done() async {
    if (_busy) return;
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final visits = ref.read(visitsRepositoryProvider);
    final visit = widget.visit;
    final planIds = _writeRecord
        ? [for (final petId in visit.petIds) ?_chosen(petId)]
        : <String>[];
    final notes = _notes.text.trim();
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final result = await visits.completeVisit(
        visit.id,
        recordKind: _writeRecord ? _kind : null,
        planIds: planIds,
        notes: notes.isEmpty ? null : notes,
      );
      container.read(appEventsProvider).action(AppAction.visitTookPlace);
      refreshVisits(container, visitId: visit.id, petIds: visit.petIds);
      if (mounted) navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.movedPlanIds.isEmpty
                ? l10n.visitDoneSaved
                : l10n.visitDoneSavedPlans(result.movedPlanIds.length),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Marking the visit done failed: $error');
      refreshVisits(container, visitId: visit.id, petIds: visit.petIds);
      if (mounted) {
        setState(
          // Cancelled meanwhile, or not yet happened (the phone's date is
          // ahead of the household's): say so rather than "check the fields".
          () => _failure = fieldErrorsOf(error).containsKey('status')
              ? l10n.visitDoneNotPossible
              : errorMessageFor(error, l10n),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final pets = {
      for (final pet in ref.watch(petsProvider).value ?? const <Pet>[])
        pet.id: pet,
    };
    final failure = _failure;

    return LeaveGuard(
      busy: _busy,
      changed: _changed,
      child: Padding(
        // Above the keyboard when the notes are typed.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CbSpace.s4,
              0,
              CbSpace.s4,
              CbSpace.s4,
            ),
            child: IgnorePointer(
              ignoring: _busy,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.visitDoneTitle, style: text.title),
                  const SizedBox(height: CbSpace.s2),
                  SwitchListTile(
                    key: const ValueKey('writeRecord'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.visitDoneWriteRecord, style: text.body),
                    subtitle: Text(l10n.visitDoneWriteRecordHelper),
                    value: _writeRecord,
                    onChanged: (value) => setState(() => _writeRecord = value),
                  ),
                  if (_writeRecord) ...[
                    const SizedBox(height: CbSpace.s2),
                    Wrap(
                      spacing: CbSpace.s2,
                      runSpacing: CbSpace.s2,
                      children: [
                        for (final kind in visitRecordKinds)
                          ChoiceChip(
                            label: Text(careKindLabel(l10n, kind)),
                            selected: _kind == kind,
                            onSelected: (_) => setState(() {
                              _kind = kind;
                              // Other plans now: start from the suggestion.
                              _plans.clear();
                              _touched.clear();
                            }),
                          ),
                      ],
                    ),
                    for (final petId in widget.visit.petIds)
                      for (final plan in _matching(petId))
                        CheckboxListTile(
                          key: ValueKey('plan-${plan.id}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l10n.visitDonePlan(plan.title),
                            style: text.body,
                          ),
                          subtitle: Text(pets[petId]?.name ?? ''),
                          value: _chosen(petId) == plan.id,
                          onChanged: (on) => setState(() {
                            _touched.add(petId);
                            if (on ?? false) {
                              _plans[petId] = plan.id;
                            } else {
                              _plans.remove(petId);
                            }
                          }),
                        ),
                  ],
                  const SizedBox(height: CbSpace.s3),
                  CbTextField(
                    key: const ValueKey('notes'),
                    label: l10n.visitDoneNotesLabel,
                    hintText: l10n.visitDoneNotesHint,
                    controller: _notes,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                  ),
                  if (failure != null) ...[
                    const SizedBox(height: CbSpace.s3),
                    CbNotice.error(message: failure),
                  ],
                  const SizedBox(height: CbSpace.s4),
                  FilledButton(
                    onPressed: _busy ? null : _done,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: CbSpace.s5,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.visitDone),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
