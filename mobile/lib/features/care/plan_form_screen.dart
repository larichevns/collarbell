import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/offline_copy.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/form_errors.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../household/current_household.dart';
import '../notifications/push_registration.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import 'care.dart';
import 'care_labels.dart';
import 'care_refresh.dart';
import 'care_repository.dart';
import 'care_rules.dart';
import 'widgets/kind_dropdown.dart';
import 'widgets/target_chips.dart';

/// Adds a plan to the pet [petId], starting from the preset [presetCode]
/// (or from scratch: "Own plan"), or edits the plan [planId].
class PlanFormScreen extends ConsumerWidget {
  const PlanFormScreen({
    super.key,
    required this.petId,
    this.planId,
    this.presetCode,
    this.draft,
  });

  final String petId;

  /// Null when adding a plan.
  final String? planId;

  /// The preset a new plan starts from; null for an own plan.
  final String? presetCode;

  /// What a new own plan starts with, e.g. from a scanned medicine.
  final CarePlanDraft? draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final planId = this.planId;
    final pet = ref.watch(petProvider(petId));
    final plan = planId == null ? null : ref.watch(carePlanProvider(planId));
    final species = pet.value?.species;
    final presets = presetCode == null || species == null
        ? null
        : ref.watch(carePresetsProvider(species));

    final petValue = pet.value;
    final planValue = plan?.value;
    final ready =
        petValue != null &&
        (plan == null || planValue != null) &&
        (presets == null || presets.value != null);
    if (ready) {
      if (planValue != null && planValue.hasUnknownValues) {
        return _ReadOnlyPlan(plan: planValue);
      }
      // An unknown code (e.g. from an old link) gives an own plan.
      final preset = presets?.value
          ?.where((preset) => preset.code == presetCode)
          .firstOrNull;
      return _PlanForm(
        pet: petValue,
        plan: planValue,
        preset: preset,
        draft: planValue == null && preset == null ? draft : null,
        initialTitle:
            planValue?.title ??
            (preset == null ? draft?.title ?? '' : presetTitle(l10n, preset)),
      );
    }

    final error = pet.error ?? plan?.error ?? presets?.error;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          planId == null ? l10n.planFormAddTitle : l10n.planFormEditTitle,
        ),
      ),
      body: error != null
          ? Center(
              child: CbErrorState(
                message: errorMessageFor(error, l10n),
                traceId: traceIdOf(error),
                onRetry: () {
                  ref.invalidate(petProvider(petId));
                  if (planId != null) ref.invalidate(carePlanProvider(planId));
                  if (species != null) {
                    ref.invalidate(carePresetsProvider(species));
                  }
                },
              ),
            )
          : const CbLoadingState.form(),
    );
  }
}

/// Deletes [plan] after asking. The records it made stay in the history,
/// and the dialog says so.
Future<void> _deletePlan(
  BuildContext context,
  WidgetRef ref,
  CarePlan plan,
) async {
  final l10n = context.l10n;
  final confirmed = await confirmDestructive(
    context,
    title: l10n.planDeleteTitle,
    message: l10n.planDeleteBody,
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
    await care.deletePlan(plan.id);
  } catch (error) {
    debugPrint('Deleting the plan failed: $error');
    // Deleted already, e.g. on another device: that is what the user wants.
    if (!isNotFound(error)) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
      return;
    }
  }
  refreshCare(container, plan.petId);
  if (context.mounted) navigator.pop();
}

class _PlanForm extends ConsumerStatefulWidget {
  const _PlanForm({
    required this.pet,
    required this.plan,
    required this.preset,
    required this.initialTitle,
    this.draft,
  });

  final Pet pet;

  /// The plan being edited, or null when adding one.
  final CarePlan? plan;

  /// The preset a new plan starts from.
  final CarePreset? preset;

  /// The plan's title, or the preset's title in the user's language.
  final String initialTitle;

  /// What a new own plan starts with.
  final CarePlanDraft? draft;

  @override
  ConsumerState<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<_PlanForm> with OpenedInHousehold {
  // The server's limits; checked here so mistakes show before saving.
  static const _maxTitle = 100;
  static const _maxProduct = 100;
  static const _maxNotes = 2000;

  final _formKey = GlobalKey<FormState>();

  /// One id for adding this plan, sent with every try. A retry after a lost
  /// response gets the plan that was added, not a second one.
  final _requestId = const Uuid().v4();
  late final _title = TextEditingController(text: widget.initialTitle);
  late var _kind =
      widget.plan?.kind ??
      widget.preset?.kind ??
      widget.draft?.kind ??
      CareKind.other;

  /// The interval the form starts with: the plan's, the preset's, or
  /// monthly for an own plan.
  late final CareInterval? _startInterval = widget.plan != null
      ? widget.plan!.interval
      : widget.preset != null
      ? widget.preset!.interval
      : widget.draft?.interval ?? const CareInterval(1, IntervalUnit.month);
  late var _repeats = _startInterval != null;
  late final _intervalValue = TextEditingController(
    text: '${_startInterval?.value ?? 1}',
  );
  late var _unit = _startInterval?.unit ?? IntervalUnit.month;

  /// When it was last done (new plans only): the next date is counted from
  /// it.
  DateTime? _lastDone;
  late DateTime? _nextDue = widget.plan?.nextDueOn ?? CbDateField.today();

  /// The next date was worked out from [_lastDone], not picked.
  var _nextDueComputed = false;
  late final _product = TextEditingController(
    text: widget.plan?.defaultProduct ?? widget.draft?.product,
  );
  late var _targets = widget.plan?.targets ?? widget.preset?.targets ?? [];
  late final _notes = TextEditingController(text: widget.plan?.notes);
  late var _active = widget.plan?.active ?? true;

  var _submitted = false;
  var _busy = false;

  /// Field errors of the last 400 response, by API field name.
  var _serverErrors = <String, List<String>>{};

  /// A failure that doesn't belong to one field.
  String? _failure;

  bool get _isEdit => widget.plan != null;

  /// The product field is shown for kinds where something is given, and
  /// whenever the plan has one, so saving never drops it unseen.
  bool get _showProduct =>
      usesProduct(_kind) || widget.plan?.defaultProduct != null;

  /// The interval as typed, or null for a one-off plan or a number that
  /// isn't valid.
  CareInterval? get _interval {
    if (!_repeats) return null;
    final value = int.tryParse(_intervalValue.text.trim());
    if (value == null || value < 1 || value > CareInterval.maxValue(_unit)) {
      return null;
    }
    return CareInterval(value, _unit);
  }

  /// Everything the form holds, to tell whether leaving loses anything.
  List<Object?> _values() => [
    _kind,
    _repeats,
    _unit,
    _lastDone,
    _nextDue,
    // The chips give the targets back in their own order: compared as a set.
    ...(_targets.map((target) => target.index).toList()..sort()),
    _targets.length,
    _active,
    for (final field in [_title, _intervalValue, _product, _notes]) field.text,
  ];

  /// What the form opened with.
  late final List<Object?> _opened;

  /// Opened from an offline copy: doesn't save (see [openedFromCopy]).
  late final bool _fromCopy;

  @override
  void initState() {
    super.initState();
    _fromCopy = widget.plan != null && openedFromCopy(ref);
    _opened = _values();
  }

  @override
  void dispose() {
    for (final controller in [_title, _intervalValue, _product, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- Validation -------------------------------------------------------

  /// The localized error the server reported for [field], if any. Server
  /// texts are English, so only the fact of the error is shown.
  String? _serverError(String field) => _serverErrors.containsKey(field)
      ? context.l10n.formServerFieldError
      : null;

  String? _maxLength(String? value, int max) =>
      (value ?? '').trim().length > max ? context.l10n.formTooLong(max) : null;

  String? _validateTitle(String? value) {
    if ((value ?? '').trim().isEmpty) return context.l10n.planTitleRequired;
    return _maxLength(value, _maxTitle) ?? _serverError('title');
  }

  String? _validateIntervalValue(String? value) {
    final max = CareInterval.maxValue(_unit);
    final number = int.tryParse((value ?? '').trim());
    if (number == null || number < 1 || number > max) {
      return context.l10n.planIntervalInvalid(max);
    }
    return _serverError('intervalValue') ?? _serverError('intervalUnit');
  }

  /// Server error keys this form shows on a field; others go to the banner.
  static final _fieldKeys = RegExp(
    r'^(kind|title|intervalValue|intervalUnit|nextDueOn|defaultProduct'
    r'|targets|notes)$',
  );

  // --- Actions ----------------------------------------------------------

  /// Counts the next date from the last time, when both it and a valid
  /// interval are there. The user can still change the result.
  void _recomputeNextDue() {
    final lastDone = _lastDone;
    final interval = _interval;
    if (lastDone == null || interval == null) return;
    _nextDue = addInterval(lastDone, interval);
    _nextDueComputed = true;
  }

  CarePlanInput _input() {
    String? clean(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    final plan = widget.plan;
    return CarePlanInput(
      kind: _kind,
      title: _title.text.trim(),
      interval: _interval,
      nextDueOn: _nextDue!,
      // Kept as they are; new plans get the server's default.
      remindOffsetsDays: plan?.remindOffsetsDays,
      defaultProduct: _showProduct ? clean(_product) : null,
      targets: usesTargets(_kind) ? _targets : const [],
      presetCode: plan?.presetCode ?? widget.preset?.code,
      notes: clean(_notes),
      // Sent only when the user changed it: null keeps the plan as it is,
      // even if another phone changed it meanwhile.
      active: plan != null && _active != plan.active ? _active : null,
    );
  }

  Future<void> _save() async {
    if (_fromCopy) {
      setState(() => _failure = context.l10n.formOpenedOffline);
      return;
    }
    if (_busy) return;
    final l10n = context.l10n;
    // Nothing can be typed while the form saves (see IgnorePointer below).
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

    // Everything is read before the first await. Leaving the form is
    // blocked while it saves (PopScope), but the app can still close it,
    // e.g. on sign-out, and the save must finish all the same.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final care = ref.read(careRepositoryProvider);
    final input = _input();
    final plan = widget.plan;
    final petId = widget.pet.id;
    setState(() => _busy = true);
    try {
      final saved = plan == null
          ? await care.createPlan(petId, input, requestId: _requestId)
          : await care.updatePlan(plan.id, input);
      refreshCare(container, petId, planId: saved.id);
      // Its reminders need notifications: asked once, after the first one.
      if (plan == null && mounted) {
        // Saved: the question comes over a finished form, not a spinner.
        setState(() => _busy = false);
        await askForPushesOnce(context, ref);
      }
      // `true` tells the preset picker to close as well.
      if (mounted) navigator.pop(true);
    } catch (error) {
      debugPrint('Saving the plan failed: $error');
      // The save may have gone through and only the answer got lost: the
      // lists reload anyway, so going back shows what the server has.
      refreshCare(container, petId, planId: plan?.id);
      if (isNotFound(error)) {
        // The plan (or, when adding, the pet) was deleted elsewhere: there
        // is nothing left to save.
        messenger.showSnackBar(
          SnackBar(
            content: Text(plan == null ? l10n.careGonePet : l10n.careGonePlan),
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
      // Shows the server's field errors under their fields, and the first
      // of them on screen.
      if (placed) revealTopmost(invalidFields(_formKey.currentState!));
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
    final plan = widget.plan;
    final preset = widget.preset;
    final presetNoteText = preset == null ? null : presetNote(l10n, preset);
    final today = CbDateField.today();
    const gap = SizedBox(height: CbSpace.s4);

    return LeaveGuard(
      busy: _busy,
      changed: () => valuesChanged(_opened, _values()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? l10n.planFormEditTitle : l10n.planFormAddTitle),
          actions: [
            if (plan != null)
              PopupMenuButton<_PlanAction>(
                tooltip: l10n.commonMoreActions,
                // ⋮ in Material Symbols, as every other icon.
                icon: const Icon(Symbols.more_vert_rounded),
                enabled: !_busy,
                onSelected: (action) => switch (action) {
                  _PlanAction.delete => _deletePlan(context, ref, plan),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _PlanAction.delete,
                    child: Row(
                      children: [
                        Icon(Symbols.delete_rounded, color: cb.danger),
                        const SizedBox(width: CbSpace.s3),
                        Text(
                          l10n.planDelete,
                          style: TextStyle(color: cb.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        bottomNavigationBar: CbSaveBar(
          busy: _busy,
          error: _failure,
          onSave: () => inOpenedHousehold(_save),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          // Not a lazy list: every field is built, so every field is checked.
          // Every field has its own key: rows that come and go (the interval,
          // the product, the targets) must not hand a field's text or error
          // to another field.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s12,
            ),
            // No input while saving: a menu or a date picker opened now
            // would be closed by the save instead of the form, and a change
            // would come too late to be saved.
            child: IgnorePointer(
              ignoring: _busy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // What the preset says, e.g. "When the risk is unknown: at
                  // least 4 times a year". Dog-only products are a warning.
                  if (preset != null && preset.dogOnly) ...[
                    CbNotice.error(
                      key: const ValueKey('presetNote'),
                      message: [l10n.presetDogOnly, ?presetNoteText].join('. '),
                    ),
                    gap,
                  ] else if (presetNoteText != null) ...[
                    CbNotice(
                      key: const ValueKey('presetNote'),
                      message: presetNoteText,
                    ),
                    gap,
                  ],
                  CbTextField(
                    key: const ValueKey('title'),
                    label: l10n.planTitleLabel,
                    hintText: l10n.planTitleHint,
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    validator: _validateTitle,
                  ),
                  gap,
                  CbLabeled(
                    key: const ValueKey('kind'),
                    label: l10n.careKindLabel,
                    child: KindDropdown(
                      value: _kind,
                      validator: (_) => _serverError('kind'),
                      onChanged: (kind) => setState(() => _kind = kind),
                    ),
                  ),
                  gap,
                  CbLabeled(
                    key: const ValueKey('repeats'),
                    label: l10n.planRepeatLabel,
                    child: SegmentedButton<bool>(
                      expandedInsets: EdgeInsets.zero,
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.planRepeats),
                        ),
                        ButtonSegment(value: false, label: Text(l10n.planOnce)),
                      ],
                      selected: {_repeats},
                      onSelectionChanged: (value) => setState(() {
                        _repeats = value.single;
                        _recomputeNextDue();
                      }),
                    ),
                  ),
                  if (_repeats) ...[
                    gap,
                    CbLabeled(
                      key: const ValueKey('interval'),
                      label: l10n.planIntervalLabel,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 96,
                            child: TextFormField(
                              controller: _intervalValue,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: text.body,
                              validator: _validateIntervalValue,
                              onChanged: (_) => setState(_recomputeNextDue),
                            ),
                          ),
                          const SizedBox(width: CbSpace.s2),
                          Expanded(
                            child: DropdownButtonFormField<IntervalUnit>(
                              icon: cbDropdownIcon,
                              initialValue: _unit,
                              isExpanded: true,
                              style: text.body.copyWith(color: cb.ink),
                              items: [
                                for (final unit in IntervalUnit.values)
                                  DropdownMenuItem(
                                    value: unit,
                                    child: Text(
                                      intervalUnitLabel(
                                        l10n,
                                        unit,
                                        int.tryParse(_intervalValue.text) ?? 1,
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (unit) {
                                if (unit == null) return;
                                setState(() {
                                  _unit = unit;
                                  _recomputeNextDue();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isEdit) ...[
                      gap,
                      CbDateField(
                        key: const ValueKey('lastDone'),
                        label: l10n.planLastDoneLabel,
                        helperText: l10n.planLastDoneHelper,
                        value: _lastDone,
                        firstDate: earliestCareDate,
                        onChanged: (date) => setState(() {
                          _lastDone = date;
                          _recomputeNextDue();
                        }),
                      ),
                    ],
                  ],
                  gap,
                  CbDateField(
                    key: const ValueKey('nextDue'),
                    label: _repeats
                        ? l10n.planNextDueLabel
                        : l10n.planDueOnLabel,
                    helperText: _nextDueComputed
                        ? l10n.planNextDueComputed
                        : null,
                    value: _nextDue,
                    firstDate: earliestCareDate,
                    lastDate: latestDueDate(today),
                    clearable: false,
                    onChanged: (date) => setState(() {
                      _nextDue = date;
                      _nextDueComputed = false;
                    }),
                    validator: (date) => date == null
                        ? l10n.dateRequired
                        : _serverError('nextDueOn'),
                  ),
                  if (_showProduct) ...[
                    gap,
                    CbTextField(
                      key: const ValueKey('product'),
                      label: l10n.planDefaultProductLabel,
                      hintText: l10n.planDefaultProductHint,
                      helperText: l10n.planDefaultProductHelper,
                      controller: _product,
                      validator: (value) =>
                          _maxLength(value, _maxProduct) ??
                          _serverError('defaultProduct'),
                    ),
                  ],
                  if (usesTargets(_kind)) ...[
                    gap,
                    TargetsFormField(
                      key: const ValueKey('targets'),
                      species: widget.pet.species,
                      selected: _targets,
                      serverError: _serverError('targets'),
                      onChanged: (targets) =>
                          setState(() => _targets = targets),
                    ),
                  ],
                  gap,
                  CbTextField(
                    key: const ValueKey('notes'),
                    label: l10n.careNotesLabel,
                    controller: _notes,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    validator: (value) =>
                        _maxLength(value, _maxNotes) ?? _serverError('notes'),
                  ),
                  if (_isEdit) ...[
                    gap,
                    SwitchListTile(
                      key: const ValueKey('active'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.planActiveLabel, style: text.body),
                      subtitle: Text(l10n.planActiveHelper),
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                    ),
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

enum _PlanAction { delete }

/// A plan with values this app doesn't know (from a newer version): its
/// details and Delete, but no form, because saving would replace them.
class _ReadOnlyPlan extends ConsumerWidget {
  const _ReadOnlyPlan({required this.plan});

  final CarePlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cb = context.cb;
    final lastDone = plan.lastDoneOn;
    final product = plan.defaultProduct;
    final notes = plan.notes;
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.planDelete,
            icon: Icon(Symbols.delete_rounded, color: cb.danger),
            onPressed: () => _deletePlan(context, ref, plan),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(CbSpace.s4),
        children: [
          CbNotice(message: l10n.planReadOnly),
          const SizedBox(height: CbSpace.s4),
          CbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CbDetailRow(
                  label: l10n.planRepeatLabel,
                  value: planIntervalLabel(l10n, plan),
                ),
                CbDetailRow(
                  label: l10n.planNextDueLabel,
                  value: l10n.dateMedium(plan.nextDueOn),
                ),
                if (lastDone != null)
                  CbDetailRow(
                    label: l10n.planLastDoneLabel,
                    value: l10n.dateMedium(lastDone),
                  ),
                if (product != null)
                  CbDetailRow(label: l10n.careProductLabel, value: product),
                if (notes != null)
                  CbDetailRow(label: l10n.careNotesLabel, value: notes),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
