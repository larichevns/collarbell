import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/offline_copy.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/form_errors.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/synced_form_field.dart';
import '../../theme/collarbell_theme.dart';
import '../care/care_labels.dart' show formatDecimal, parseDecimal;
import '../household/current_household.dart';
import '../notifications/push_registration.dart';
import '../notifications/widgets/push_off_notice.dart';
import '../supplies/supplies_repository.dart';
import '../supplies/supply.dart';
import 'feeding.dart';
import 'feeding_labels.dart';
import 'feeding_refresh.dart';
import 'feeding_repository.dart';

/// Adds a feeding schedule to the pet [petId], or edits the schedule
/// [scheduleId]: times of day, days of the week, food and portion.
class FeedingFormScreen extends ConsumerWidget {
  const FeedingFormScreen({super.key, required this.petId, this.scheduleId});

  final String petId;
  final String? scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = scheduleId;
    if (id == null) return _FeedingForm(petId: petId);

    final schedule = ref.watch(feedingScheduleProvider(id));
    final value = schedule.value;
    if (value == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.feedingEditTitle)),
        body: schedule.hasError
            ? Center(
                child: CbErrorState(
                  message: errorMessageFor(schedule.error!, l10n),
                  traceId: traceIdOf(schedule.error!),
                  onRetry: () => ref.invalidate(feedingScheduleProvider(id)),
                ),
              )
            : const CbLoadingState.form(),
      );
    }
    if (value.hasUnknownValues) {
      // Saving would replace values a newer version of the app set.
      return Scaffold(
        appBar: AppBar(title: Text(l10n.feedingEditTitle)),
        body: Padding(
          padding: const EdgeInsets.all(CbSpace.s4),
          child: CbNotice(message: l10n.feedingReadOnly),
        ),
      );
    }
    return _FeedingForm(petId: petId, schedule: value);
  }
}

class _FeedingForm extends ConsumerStatefulWidget {
  const _FeedingForm({required this.petId, this.schedule});

  final String petId;
  final FeedingSchedule? schedule;

  @override
  ConsumerState<_FeedingForm> createState() => _FeedingFormState();
}

class _FeedingFormState extends ConsumerState<_FeedingForm>
    with OpenedInHousehold {
  // The server's limits; checked here so mistakes show before saving.
  static const _maxTimes = 8;
  static const _maxFood = 100;
  static const _maxNotes = 500;
  static const _maxAmount = 10000;

  final _formKey = GlobalKey<FormState>();

  /// One id for adding this schedule, sent with every try. A retry after a
  /// lost response gets the schedule that was added, not a second one.
  final _requestId = const Uuid().v4();

  late var _times = [...?widget.schedule?.times];
  late var _days = [...(widget.schedule?.days ?? everyDay)];
  late final _food = TextEditingController(text: widget.schedule?.food);
  late final _amount = TextEditingController(
    text: widget.schedule?.amount == null
        ? null
        : formatDecimal(context.l10n, widget.schedule!.amount!),
  );
  late var _unit = widget.schedule?.unit ?? PortionUnit.gram;
  late final _notes = TextEditingController(text: widget.schedule?.notes);
  late var _active = widget.schedule?.active ?? true;

  /// The food in supplies it gives, if any: then the food is its name and
  /// the portion is in its unit.
  late String? _supplyId = widget.schedule?.supplyItemId;

  var _submitted = false;
  var _busy = false;

  /// Field errors of the last 400 response, by API field name.
  var _serverErrors = <String, List<String>>{};

  /// A failure that doesn't belong to one field.
  String? _failure;

  bool get _isEdit => widget.schedule != null;

  /// Everything the form holds, to tell whether leaving loses anything.
  List<Object?> _values() => [
    ..._times,
    _times.length,
    // Days compare by content, whatever order the taps came in.
    ...(List.of(_days)..sort()),
    _days.length,
    for (final field in [_food, _amount, _notes]) field.text,
    _unit,
    _active,
    _supplyId,
  ];

  /// What the form opened with. Taken once the context can give the
  /// locale: the portion is shown with the user's decimal separator.
  List<Object?>? _opened;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _opened ??= _values();
  }

  /// Opened from an offline copy: doesn't save (see [openedFromCopy]).
  late final bool _fromCopy;

  @override
  void initState() {
    super.initState();
    _fromCopy = widget.schedule != null && openedFromCopy(ref);
  }

  @override
  void dispose() {
    for (final controller in [_food, _amount, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- Validation -------------------------------------------------------

  String? _serverError(String field) => _serverErrors.containsKey(field)
      ? context.l10n.formServerFieldError
      : null;

  String? _maxLength(String? value, int max) =>
      (value ?? '').trim().length > max ? context.l10n.formTooLong(max) : null;

  /// Up to 5 digits and 2 decimals, with a point or a comma. Checked on the
  /// text: as a double, 2.2 × 100 isn't exactly 220.
  static final _amountPattern = RegExp(r'^\d{1,5}([.,]\d{1,2})?$');

  String? _validateAmount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final amount = parseDecimal(text);
    if (!_amountPattern.hasMatch(text) ||
        amount == null ||
        amount <= 0 ||
        amount > _maxAmount) {
      return context.l10n.feedingAmountInvalid;
    }
    return _serverError('amount') ?? _serverError('unit');
  }

  static final _fieldKeys = RegExp(
    r'^(times|days|food|amount|unit|notes|supplyItemId)$',
  );

  /// The supplies a feeding can give: food the household buys, counted in
  /// a unit a portion can have; and the one already linked.
  List<Supply> _choosableSupplies(List<Supply> supplies) => [
    for (final supply in supplies)
      if ((supply.active &&
              isFood(supply.category) &&
              portionUnitFor(supply.unit) != null) ||
          supply.id == widget.schedule?.supplyItemId)
        supply,
  ];

  Supply? get _linkedSupply {
    final id = _supplyId;
    if (id == null) return null;
    for (final supply in ref.read(suppliesProvider).value ?? const <Supply>[]) {
      if (supply.id == id) return supply;
    }
    return null;
  }

  // --- Actions ----------------------------------------------------------

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times.isEmpty
          ? const TimeOfDay(hour: 8, minute: 0)
          : TimeOfDay(hour: (_times.last.hour + 12) % 24, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (!_times.contains(picked)) {
        _times = [..._times, picked]
          ..sort((a, b) => minutesOf(a) - minutesOf(b));
      }
    });
  }

  FeedingInput _input() {
    String? clean(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    final amount = parseDecimal(_amount.text);
    final schedule = widget.schedule;
    final supply = _linkedSupply;
    return FeedingInput(
      times: _times,
      days: [..._days]..sort(),
      food: supply?.name ?? clean(_food),
      amount: amount,
      unit: amount == null
          ? null
          : (supply == null ? _unit : portionUnitFor(supply.unit) ?? _unit),
      notes: clean(_notes),
      // Sent only when the user changed it: null keeps it as it is.
      active: schedule != null && _active != schedule.active ? _active : null,
      supplyItemId: _supplyId,
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
    // form (e.g. on sign-out) and the save must finish all the same.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final feeding = ref.read(feedingRepositoryProvider);
    final input = _input();
    final schedule = widget.schedule;
    final petId = widget.petId;
    setState(() => _busy = true);
    try {
      final saved = schedule == null
          ? await feeding.createSchedule(petId, input, requestId: _requestId)
          : await feeding.updateSchedule(schedule.id, input);
      refreshFeeding(container, petId, scheduleId: saved.id);
      // Its reminders need notifications: asked once, after the first one.
      if (schedule == null && mounted) {
        // Saved: the question comes over a finished form, not a spinner.
        setState(() => _busy = false);
        await askForPushesOnce(context, ref);
      }
      if (mounted) navigator.pop();
    } catch (error) {
      debugPrint('Saving the feeding schedule failed: $error');
      // The save may have gone through and only the answer got lost.
      refreshFeeding(container, petId, scheduleId: schedule?.id);
      if (isNotFound(error)) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              schedule == null ? l10n.careGonePet : l10n.feedingGone,
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

  Future<void> _delete() async {
    final schedule = widget.schedule!;
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.feedingDeleteTitle,
      message: l10n.feedingDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final feeding = ref.read(feedingRepositoryProvider);
    setState(() => _busy = true);
    try {
      await feeding.deleteSchedule(schedule.id);
      refreshFeeding(container, widget.petId);
      if (mounted) navigator.pop();
    } catch (error) {
      debugPrint('Deleting the feeding schedule failed: $error');
      refreshFeeding(container, widget.petId, scheduleId: schedule.id);
      if (isNotFound(error)) {
        // Deleted elsewhere already: what the user wanted.
        if (mounted) navigator.pop();
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Layout -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    const gap = SizedBox(height: CbSpace.s5);
    // Without supplies (or while they load) there is just the food's name.
    final supplies = _choosableSupplies(
      ref.watch(suppliesProvider).value ?? const [],
    );
    final linked = _linkedSupply;
    final linkedUnit = linked == null ? null : portionUnitFor(linked.unit);

    return LeaveGuard(
      busy: _busy,
      changed: () => valuesChanged(_opened!, _values()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? l10n.feedingEditTitle : l10n.feedingAddTitle),
          actions: [
            if (_isEdit)
              IconButton(
                tooltip: l10n.feedingDelete,
                icon: Icon(Symbols.delete_rounded, color: cb.danger),
                onPressed: _busy ? null : _delete,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s12,
            ),
            child: IgnorePointer(
              ignoring: _busy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SyncedFormField<List<TimeOfDay>>(
                    key: const ValueKey('times'),
                    initialValue: _times,
                    validator: (_) => _times.isEmpty
                        ? l10n.feedingTimesRequired
                        : _times.length > _maxTimes
                        ? l10n.feedingTimesTooMany(_maxTimes)
                        : _serverError('times'),
                    builder: (field) => CbLabeled(
                      label: l10n.feedingTimesLabel,
                      errorText: field.errorText,
                      child: Wrap(
                        spacing: CbSpace.s2,
                        runSpacing: CbSpace.s2,
                        children: [
                          for (final time in _times)
                            InputChip(
                              key: ValueKey('time-${minutesOf(time)}'),
                              label: Text(timeLabel(context, time)),
                              deleteButtonTooltipMessage:
                                  l10n.feedingTimeRemove,
                              onDeleted: () => setState(
                                () => _times = [..._times]..remove(time),
                              ),
                            ),
                          if (_times.length < _maxTimes)
                            ActionChip(
                              key: const ValueKey('addTime'),
                              avatar: const Icon(Symbols.add_rounded),
                              label: Text(l10n.feedingTimeAdd),
                              onPressed: _addTime,
                            ),
                        ],
                      ),
                    ),
                  ),
                  gap,
                  SyncedFormField<List<int>>(
                    key: const ValueKey('days'),
                    initialValue: _days,
                    validator: (_) => _days.isEmpty
                        ? l10n.feedingDaysRequired
                        : _serverError('days'),
                    builder: (field) => CbLabeled(
                      label: l10n.feedingDaysLabel,
                      errorText: field.errorText,
                      child: Wrap(
                        spacing: CbSpace.s2,
                        runSpacing: CbSpace.s2,
                        children: [
                          for (final day in everyDay)
                            FilterChip(
                              label: Text(weekdayShort(l10n, day)),
                              selected: _days.contains(day),
                              onSelected: (on) => setState(
                                () => _days = on ? [..._days, day] : [..._days]
                                  ..remove(day),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  gap,
                  if (supplies.isNotEmpty) ...[
                    CbLabeled(
                      label: l10n.feedingSupplyLabel,
                      helperText: l10n.feedingSupplyHelper,
                      errorText: _serverError('supplyItemId'),
                      child: DropdownButtonFormField<String?>(
                        icon: cbDropdownIcon,
                        key: const ValueKey('supply'),
                        initialValue: _supplyId,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l10n.feedingSupplyNone),
                          ),
                          for (final supply in supplies)
                            DropdownMenuItem(
                              value: supply.id,
                              child: Text(
                                supply.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) => setState(() {
                          _supplyId = id;
                          final supply = _linkedSupply;
                          final unit = supply == null
                              ? null
                              : portionUnitFor(supply.unit);
                          if (unit != null) _unit = unit;
                        }),
                      ),
                    ),
                    gap,
                  ],
                  if (linked == null)
                    CbTextField(
                      key: const ValueKey('food'),
                      label: l10n.feedingFoodLabel,
                      hintText: l10n.feedingFoodHint,
                      controller: _food,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) =>
                          _maxLength(value, _maxFood) ?? _serverError('food'),
                    ),
                  gap,
                  CbLabeled(
                    key: const ValueKey('portion'),
                    label: l10n.feedingPortionLabel,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 112,
                          child: TextFormField(
                            controller: _amount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            style: text.body,
                            decoration: InputDecoration(
                              hintText: l10n.feedingAmountHint,
                            ),
                            validator: _validateAmount,
                          ),
                        ),
                        const SizedBox(width: CbSpace.s2),
                        Expanded(
                          child: SegmentedButton<PortionUnit>(
                            showSelectedIcon: false,
                            segments: [
                              for (final unit in PortionUnit.values)
                                ButtonSegment(
                                  value: unit,
                                  label: Text(portionUnitLabel(l10n, unit)),
                                  // A food in supplies is counted in its
                                  // unit: the portion must be in it too.
                                  enabled:
                                      linkedUnit == null || unit == linkedUnit,
                                ),
                            ],
                            selected: {linkedUnit ?? _unit},
                            onSelectionChanged: (value) =>
                                setState(() => _unit = value.single),
                          ),
                        ),
                      ],
                    ),
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('notes'),
                    label: l10n.careNotesLabel,
                    controller: _notes,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    validator: (value) =>
                        _maxLength(value, _maxNotes) ?? _serverError('notes'),
                  ),
                  if (_isEdit) ...[
                    gap,
                    SwitchListTile(
                      key: const ValueKey('active'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.feedingActiveLabel, style: text.body),
                      subtitle: Text(l10n.feedingActiveHelper),
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                    ),
                  ],
                  gap,
                  CbNotice(message: l10n.feedingRemindersNote),
                  // ...unless notifications were refused on this phone.
                  const PushOffNotice(
                    padding: EdgeInsets.only(top: CbSpace.s2),
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
