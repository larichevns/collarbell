import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/offline_copy.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/cb_time_field.dart';
import '../../shared/widgets/form_errors.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/synced_form_field.dart';
import '../../theme/collarbell_theme.dart';
import '../household/current_household.dart';
import '../notifications/push_registration.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import 'visit.dart';
import 'visit_labels.dart';
import 'visit_refresh.dart';
import 'visits_repository.dart';

/// Adds a visit, or edits the visit [visitId]. [petId] preselects a pet for
/// a new visit.
class VisitFormScreen extends ConsumerWidget {
  const VisitFormScreen({super.key, this.visitId, this.petId});

  final String? visitId;
  final String? petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pets = ref.watch(petsProvider);
    final id = visitId;
    final visit = id == null ? null : ref.watch(visitProvider(id));
    final title = id == null ? l10n.visitAddTitle : l10n.visitEditTitle;

    // The form stays once it has its data, also when a reload after a failed
    // save fails too: rebuilding it would lose what the user typed.
    final petList = pets.value;
    final value = visit?.value;
    if (petList != null && (visit == null || value != null)) {
      if (value != null && value.hasUnknownValues) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Padding(
            padding: const EdgeInsets.all(CbSpace.s4),
            child: CbNotice(message: l10n.visitReadOnly),
          ),
        );
      }
      return _VisitForm(visit: value, pets: petList, petId: petId);
    }

    final error = pets.error ?? visit?.error;
    if (error != null && !(pets.isLoading || (visit?.isLoading ?? false))) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: CbErrorState(
            message: errorMessageFor(error, l10n),
            traceId: traceIdOf(error),
            onRetry: () {
              ref.invalidate(petsProvider);
              if (id != null) ref.invalidate(visitProvider(id));
            },
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const CbLoadingState.form(),
    );
  }
}

class _VisitForm extends ConsumerStatefulWidget {
  const _VisitForm({required this.pets, this.visit, this.petId});

  final Visit? visit;
  final List<Pet> pets;
  final String? petId;

  @override
  ConsumerState<_VisitForm> createState() => _VisitFormState();
}

class _VisitFormState extends ConsumerState<_VisitForm> with OpenedInHousehold {
  static const _maxTitle = 100;
  static const _maxLocation = 200;
  static const _maxNotes = 2000;

  final _formKey = GlobalKey<FormState>();

  /// One id for adding this visit, sent with every try.
  final _requestId = const Uuid().v4();

  late var _type = widget.visit?.type ?? VisitType.vet;
  late final _title = TextEditingController(text: widget.visit?.title);
  late DateTime? _date = widget.visit?.date;
  late TimeOfDay? _time = widget.visit?.time;
  late var _petIds = widget.visit?.petIds.toSet() ?? _initialPets();
  late final _location = TextEditingController(text: widget.visit?.location);
  late final _notes = TextEditingController(text: widget.visit?.notes);
  late var _reminders =
      (widget.visit?.remindMinutesBefore ?? defaultVisitReminders).toSet();

  var _submitted = false;
  var _busy = false;
  var _serverErrors = <String, List<String>>{};
  String? _failure;

  bool get _isEdit => widget.visit != null;

  /// The pets a visit can be for: the active ones, and any the visit
  /// already has.
  List<Pet> get _choosable => [
    for (final pet in widget.pets)
      if (pet.isActive || (widget.visit?.petIds.contains(pet.id) ?? false)) pet,
  ];

  /// The pet the form was opened for, or the only one.
  Set<String> _initialPets() {
    final petId = widget.petId;
    if (petId != null) return {petId};
    final active = [
      for (final pet in widget.pets)
        if (pet.isActive) pet.id,
    ];
    return active.length == 1 ? {active.single} : {};
  }

  /// Everything the form holds, to tell whether leaving loses anything.
  List<Object?> _values() => [
    _type,
    _date,
    _time,
    for (final field in [_title, _location, _notes]) field.text,
    // Sets compare by content, whatever order the taps came in.
    ...(_petIds.toList()..sort()),
    _petIds.length,
    ...(_reminders.toList()..sort()),
    _reminders.length,
  ];

  /// What the form opened with.
  late final List<Object?> _opened;

  /// Opened from an offline copy: doesn't save (see [openedFromCopy]).
  late final bool _fromCopy;

  @override
  void initState() {
    super.initState();
    _fromCopy = widget.visit != null && openedFromCopy(ref);
    _opened = _values();
  }

  @override
  void dispose() {
    for (final controller in [_title, _location, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _serverError(String field) => _serverErrors.containsKey(field)
      ? context.l10n.formServerFieldError
      : null;

  String? _maxLength(String? value, int max) =>
      (value ?? '').trim().length > max ? context.l10n.formTooLong(max) : null;

  static final _fieldKeys = RegExp(
    r'^(type|title|date|time|location|notes|petIds|remindOffsetsMinutes)$',
  );

  VisitInput _input() {
    String? clean(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    return VisitInput(
      type: _type,
      // No title typed: the kind of visit says what it is.
      title: clean(_title) ?? visitTypeLabel(context.l10n, _type),
      date: _date!,
      time: _time!,
      petIds: [
        for (final pet in widget.pets)
          if (_petIds.contains(pet.id)) pet.id,
      ],
      remindMinutesBefore: _reminders.toList()..sort((a, b) => b - a),
      durationMinutes: widget.visit?.durationMinutes,
      location: clean(_location),
      notes: clean(_notes),
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

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final visits = ref.read(visitsRepositoryProvider);
    final input = _input();
    final visit = widget.visit;
    setState(() => _busy = true);
    try {
      final saved = visit == null
          ? await visits.createVisit(input, requestId: _requestId)
          : await visits.updateVisit(visit.id, input);
      refreshVisits(container, visitId: saved.id);
      // Its reminders need notifications: asked once, after the first one.
      if (visit == null && mounted) {
        // Saved: the question comes over a finished form, not a spinner.
        setState(() => _busy = false);
        await askForPushesOnce(context, ref);
      }
      if (mounted) navigator.pop();
    } catch (error) {
      debugPrint('Saving the visit failed: $error');
      refreshVisits(container, visitId: visit?.id);
      if (isNotFound(error) && visit != null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.visitGone)));
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = CbDateField.today();
    const gap = SizedBox(height: CbSpace.s5);
    // Reminders set elsewhere (another phone, a newer app) stay choosable.
    final reminderChoices = {...visitReminderChoices, ..._reminders}.toList()
      ..sort((a, b) => b - a);

    return LeaveGuard(
      busy: _busy,
      changed: () => valuesChanged(_opened, _values()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? l10n.visitEditTitle : l10n.visitAddTitle),
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
                  CbLabeled(
                    key: const ValueKey('type'),
                    label: l10n.visitTypeLabel,
                    errorText: _serverError('type'),
                    child: Wrap(
                      spacing: CbSpace.s2,
                      runSpacing: CbSpace.s2,
                      children: [
                        for (final type in VisitType.values)
                          ChoiceChip(
                            // Chosen: mint, the icon and words green. No tick:
                            // Material draws it over the icon on a dark disc.
                            showCheckmark: false,
                            avatar: Icon(visitTypeIcon(type)),
                            label: Text(visitTypeLabel(l10n, type)),
                            selected: _type == type,
                            onSelected: (_) => setState(() => _type = type),
                          ),
                      ],
                    ),
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('title'),
                    label: l10n.visitTitleLabel,
                    hintText: l10n.visitTitleHint,
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) =>
                        _maxLength(value, _maxTitle) ?? _serverError('title'),
                  ),
                  gap,
                  CbDateField(
                    key: const ValueKey('date'),
                    label: l10n.visitDateLabel,
                    value: _date,
                    firstDate: DateTime(today.year - 1, today.month, today.day),
                    lastDate: DateTime(today.year + 5, today.month, today.day),
                    clearable: false,
                    onChanged: (date) => setState(() => _date = date),
                    validator: (date) =>
                        date == null ? l10n.dateRequired : _serverError('date'),
                  ),
                  gap,
                  CbTimeField(
                    key: const ValueKey('time'),
                    label: l10n.visitTimeLabel,
                    value: _time,
                    onChanged: (time) => setState(() => _time = time),
                    validator: (time) => time == null
                        ? l10n.visitTimeRequired
                        : _serverError('time'),
                  ),
                  gap,
                  SyncedFormField<Set<String>>(
                    key: const ValueKey('pets'),
                    initialValue: _petIds,
                    validator: (_) => _petIds.isEmpty
                        ? l10n.visitPetsRequired
                        : _serverError('petIds'),
                    builder: (field) => CbLabeled(
                      label: l10n.visitPetsLabel,
                      errorText: field.errorText,
                      child: Wrap(
                        spacing: CbSpace.s2,
                        runSpacing: CbSpace.s2,
                        children: [
                          for (final pet in _choosable)
                            FilterChip(
                              label: Text(pet.name),
                              selected: _petIds.contains(pet.id),
                              onSelected: (on) => setState(
                                () => _petIds = on
                                    ? {..._petIds, pet.id}
                                    : ({..._petIds}..remove(pet.id)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('location'),
                    label: l10n.visitLocationLabel,
                    hintText: l10n.visitLocationHint,
                    controller: _location,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) =>
                        _maxLength(value, _maxLocation) ??
                        _serverError('location'),
                  ),
                  gap,
                  CbLabeled(
                    key: const ValueKey('reminders'),
                    label: l10n.visitRemindersLabel,
                    errorText: _serverError('remindOffsetsMinutes'),
                    helperText: _reminders.isEmpty
                        ? l10n.visitRemindersNone
                        : null,
                    child: Wrap(
                      spacing: CbSpace.s2,
                      runSpacing: CbSpace.s2,
                      children: [
                        for (final minutes in reminderChoices)
                          FilterChip(
                            label: Text(visitReminderLabel(l10n, minutes)),
                            selected: _reminders.contains(minutes),
                            onSelected: (on) => setState(
                              () => _reminders = on
                                  ? {..._reminders, minutes}
                                  : ({..._reminders}..remove(minutes)),
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
                    maxLines: 4,
                    validator: (value) =>
                        _maxLength(value, _maxNotes) ?? _serverError('notes'),
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
