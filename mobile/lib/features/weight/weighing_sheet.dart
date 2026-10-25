import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/offline_copy.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/form_errors.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/synced_form_field.dart';
import '../../theme/collarbell_theme.dart';
import '../care/care_labels.dart' show parseDecimal;
import '../household/current_household.dart';
import '../pets/pet.dart';
import 'weight.dart';
import 'weight_labels.dart';
import 'weight_refresh.dart';
import 'weight_repository.dart';

/// Adds a weighing of [pet], or changes or deletes [weighing]: the day, the
/// weight in kilograms (to the gram), a body condition score when the user
/// wants one, and a note.
Future<void> showWeighingSheet(
  BuildContext context, {
  required Pet pet,
  WeightEntry? weighing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  // A swipe down would close it at once and lose what was typed: Back and a
  // tap outside ask first instead (LeaveGuard).
  enableDrag: false,
  builder: (context) => _WeighingSheet(pet: pet, weighing: weighing),
);

class _WeighingSheet extends ConsumerStatefulWidget {
  const _WeighingSheet({required this.pet, this.weighing});

  final Pet pet;

  /// The weighing being changed, or null when adding one.
  final WeightEntry? weighing;

  @override
  ConsumerState<_WeighingSheet> createState() => _WeighingSheetState();
}

class _WeighingSheetState extends ConsumerState<_WeighingSheet>
    with OpenedInHousehold {
  final _formKey = GlobalKey<FormState>();

  /// One id for adding this weighing, sent with every try. A retry after a
  /// lost response gets the weighing that was added, not a second one.
  final _requestId = const Uuid().v4();

  late DateTime? _measuredOn =
      widget.weighing?.measuredOn ?? CbDateField.today();

  // Shown with the user's decimal separator ("4,2" in Russian): the context
  // gives the locale once the field is first used, in didChangeDependencies.
  late final _weight = TextEditingController(
    text: switch (widget.weighing) {
      final weighing? => weightNumberLabel(context.l10n, weighing.weightKg),
      null => null,
    },
  );
  late final _note = TextEditingController(text: widget.weighing?.note);

  /// The body condition score is folded away until the user asks for it.
  late var _showScore = widget.weighing?.bodyCondition != null;
  late var _scale =
      widget.weighing?.bodyCondition?.scale ?? BodyCondition.scales.first;
  late int? _score = widget.weighing?.bodyCondition?.score;

  var _submitted = false;
  var _busy = false;

  /// Field errors of the last 400 response, by API field name.
  var _serverErrors = <String, List<String>>{};

  /// A failure that doesn't belong to one field.
  String? _failure;

  bool get _isEdit => widget.weighing != null;

  /// Everything the sheet holds, to tell whether closing loses anything.
  List<Object?> _values() => [
    _measuredOn,
    _weight.text,
    _showScore,
    _scale,
    _score,
    _note.text,
  ];

  /// What the sheet opened with, once the locale is known (see [_weight]).
  List<Object?>? _opened;

  /// Opened from an offline copy: doesn't save (see [openedFromCopy]).
  late final bool _fromCopy;

  @override
  void initState() {
    super.initState();
    _fromCopy = widget.weighing != null && openedFromCopy(ref);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _opened ??= _values();
  }

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  // --- Validation -------------------------------------------------------

  String? _serverError(String field) => _serverErrors.containsKey(field)
      ? context.l10n.formServerFieldError
      : null;

  static final _fieldKeys = RegExp(
    r'^(measuredOn|weightKg|bcs|bcsScale|note)$',
  );

  String? _validateDate(DateTime? date, DateTime first) {
    final l10n = context.l10n;
    if (date == null) return l10n.dateRequired;
    if (date.isBefore(WeightRules.earliestDate)) return l10n.scanDateTooEarly;
    // Like the server, the birth date only checks a new date: a weighing
    // made before the pet's birth date was set keeps its date, and its note
    // can still be fixed.
    if (date.isBefore(first) && date != widget.weighing?.measuredOn) {
      return l10n.weightDateBeforeBirth;
    }
    return _serverError('measuredOn');
  }

  // --- Actions ----------------------------------------------------------

  WeighingInput _input() {
    final note = _note.text.trim();
    final score = _score;
    return WeighingInput(
      measuredOn: _measuredOn!,
      weightKg: parseDecimal(_weight.text)!,
      // An open score without a pick says nothing: it isn't sent.
      bodyCondition: _showScore && score != null
          ? BodyCondition(score, _scale)
          : null,
      note: note.isEmpty ? null : note,
    );
  }

  Future<void> _save() async {
    if (_fromCopy) {
      setState(() => _failure = context.l10n.formOpenedOffline);
      return;
    }
    if (_busy) return;
    final l10n = context.l10n;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitted = true;
      _serverErrors = {};
      _failure = null;
    });
    final invalid = invalidFields(_formKey.currentState!);
    if (invalid.isNotEmpty) {
      revealTopmost(invalid);
      setState(() => _failure = l10n.formCheckFields);
      return;
    }

    // Everything is read before the first await: the app can close the
    // sheet (e.g. on sign-out) and the save must finish all the same.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final weights = ref.read(weightRepositoryProvider);
    final input = _input();
    final weighing = widget.weighing;
    final petId = widget.pet.id;
    setState(() => _busy = true);
    try {
      if (weighing == null) {
        final added = await weights.createWeighing(
          petId,
          input,
          requestId: _requestId,
        );
        // A retry after a lost answer gets back the weighing the first try
        // added, as it was then. If the user corrected something since, the
        // correction goes after it.
        if (!_holds(added, input)) {
          await weights.updateWeighing(added.id, input);
        }
      } else {
        await weights.updateWeighing(weighing.id, input);
      }
      refreshWeight(container, petId);
      if (mounted) navigator.pop();
    } catch (error) {
      debugPrint('Saving the weighing failed: $error');
      // The save may have gone through and only the answer got lost.
      refreshWeight(container, petId);
      if (isNotFound(error)) {
        // The weighing (or, when adding, the pet) was deleted elsewhere:
        // there is nothing left to save.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              weighing == null ? l10n.careGonePet : l10n.weightGone,
            ),
          ),
        );
        if (mounted) navigator.pop();
        return;
      }
      if (!mounted) return;
      final fieldErrors = fieldErrorsOf(error);
      final placed =
          fieldErrors.isNotEmpty &&
          fieldErrors.keys.every((key) => _fieldKeys.hasMatch(key));
      setState(() {
        _serverErrors = {...fieldErrors};
        _failure = placed ? l10n.formCheckFields : errorMessageFor(error, l10n);
      });
      if (placed) revealTopmost(invalidFields(_formKey.currentState!));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Whether [saved] is what [input] says, as the server keeps it: the
  /// weight to the gram, the note trimmed.
  static bool _holds(WeightEntry saved, WeighingInput input) =>
      saved.measuredOn == input.measuredOn &&
      saved.grams == (input.weightKg * 1000).round() &&
      saved.bodyCondition == input.bodyCondition &&
      (saved.note ?? '') == (input.note ?? '');

  Future<void> _delete() async {
    final weighing = widget.weighing!;
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.weightDeleteTitle,
      message: l10n.weightDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !mounted) return;

    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final weights = ref.read(weightRepositoryProvider);
    final petId = widget.pet.id;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await weights.deleteWeighing(weighing.id);
      refreshWeight(container, petId);
      if (mounted) navigator.pop();
    } catch (error) {
      debugPrint('Deleting the weighing failed: $error');
      refreshWeight(container, petId);
      if (isNotFound(error)) {
        // Deleted elsewhere already: what the user wanted.
        if (mounted) navigator.pop();
        return;
      }
      if (mounted) setState(() => _failure = errorMessageFor(error, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Layout -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final weighing = widget.weighing;
    final failure = _failure;
    final title = Semantics(
      header: true,
      child: Text(
        _isEdit ? l10n.weightEditTitle : l10n.weightAddTitle,
        style: text.title,
      ),
    );
    const gap = SizedBox(height: CbSpace.s4);

    if (weighing != null && weighing.hasUnknownValues) {
      // Saving would replace values a newer version of the app set.
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CbSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              gap,
              CbNotice(message: l10n.weightReadOnly),
            ],
          ),
        ),
      );
    }

    final first = WeightRules.firstDateFor(widget.pet, CbDateField.today());
    return LeaveGuard(
      busy: _busy,
      changed: () => valuesChanged(_opened!, _values()),
      child: Padding(
        // Above the keyboard while the weight or the note is typed.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(CbSpace.s4),
              // No input while saving: a change would come too late to be
              // saved.
              child: IgnorePointer(
                ignoring: _busy,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: title),
                        if (_isEdit)
                          IconButton(
                            tooltip: l10n.weightDelete,
                            icon: Icon(
                              Symbols.delete_rounded,
                              color: cb.danger,
                            ),
                            onPressed: _busy ? null : _delete,
                          ),
                      ],
                    ),
                    gap,
                    CbDateField(
                      key: const ValueKey('measuredOn'),
                      label: l10n.weightMeasuredOnLabel,
                      value: _measuredOn,
                      firstDate: first,
                      clearable: false,
                      onChanged: (date) => setState(() => _measuredOn = date),
                      validator: (date) => _validateDate(date, first),
                    ),
                    gap,
                    CbTextField(
                      key: const ValueKey('weight'),
                      label: l10n.recordWeightLabel,
                      hintText: l10n.weightHint,
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      validator: (value) =>
                          weightTextProblem(
                            l10n,
                            value ?? '',
                            decimals: WeightRules.weighingDecimals,
                            required: true,
                          ) ??
                          _serverError('weightKg'),
                    ),
                    gap,
                    _scoreField(context),
                    gap,
                    CbTextField(
                      key: const ValueKey('note'),
                      label: l10n.weightNoteLabel,
                      hintText: l10n.weightNoteHint,
                      controller: _note,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      validator: (value) =>
                          (value ?? '').trim().length > WeightRules.maxNote
                          ? l10n.formTooLong(WeightRules.maxNote)
                          : _serverError('note'),
                    ),
                    if (failure != null) ...[
                      const SizedBox(height: CbSpace.s3),
                      CbNotice.error(message: failure),
                    ],
                    gap,
                    FilledButton(
                      key: const ValueKey('saveWeighing'),
                      onPressed: _busy ? null : () => inOpenedHousehold(_save),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: CbSpace.s5,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.commonSave),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The body condition score: folded into a button until asked for, then
  /// the scale, the scores as chips and the ideal ones under them.
  Widget _scoreField(BuildContext context) {
    final l10n = context.l10n;
    if (!_showScore) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          key: const ValueKey('addScore'),
          style: cbCompactOutlinedButtonStyle,
          onPressed: () => setState(() => _showScore = true),
          icon: const Icon(Symbols.add_rounded),
          label: Text(l10n.weightBcsAdd),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SyncedFormField<int>(
          key: const ValueKey('score'),
          initialValue: _score,
          validator: (_) => _serverError('bcs') ?? _serverError('bcsScale'),
          builder: (field) => CbLabeled(
            label: l10n.weightBcsLabel,
            helperText: l10n.weightBcsHelp(bodyConditionIdeal(_scale), _scale),
            errorText: field.errorText,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<int>(
                  key: const ValueKey('scale'),
                  showSelectedIcon: false,
                  segments: [
                    for (final scale in BodyCondition.scales)
                      ButtonSegment(
                        value: scale,
                        label: Text(l10n.weightBcsScale(scale)),
                      ),
                  ],
                  selected: {_scale},
                  onSelectionChanged: (value) => setState(() {
                    // A score on one scale means nothing on the other.
                    if (value.single != _scale) _score = null;
                    _scale = value.single;
                  }),
                ),
                const SizedBox(height: CbSpace.s3),
                Wrap(
                  spacing: CbSpace.s2,
                  runSpacing: CbSpace.s2,
                  children: [
                    for (var score = 1; score <= _scale; score++)
                      ChoiceChip(
                        key: ValueKey('score-$score'),
                        label: Text('$score'),
                        showCheckmark: false,
                        selected: _score == score,
                        onSelected: (on) =>
                            setState(() => _score = on ? score : null),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('removeScore'),
          onPressed: () => setState(() {
            _showScore = false;
            _score = null;
            _scale = BodyCondition.scales.first;
          }),
          child: Text(l10n.weightBcsRemove),
        ),
      ],
    );
  }
}
