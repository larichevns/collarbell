import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/offline_copy.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/cb_time_field.dart';
import '../../shared/widgets/form_errors.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../files/files_repository.dart';
import '../files/media_picker.dart';
import '../household/current_household.dart';
import '../pets/pets_repository.dart';
import 'care.dart';
import 'care_labels.dart';
import 'care_refresh.dart';
import 'care_repository.dart';
import 'care_rules.dart';
import 'widgets/due_line.dart';
import 'widgets/kind_icon.dart';
import 'widgets/record_photos.dart';

/// "Done" for the plan [planId], from the Health tab or from Today: when it
/// was done, what was given, photos of the sticker, and the plan's next
/// date (worked out like the server does, or chosen by the user).
class DoneScreen extends ConsumerWidget {
  const DoneScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(carePlanProvider(planId));
    final value = plan.value;
    if (value != null) return _DoneForm(plan: value);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.doneTitle)),
      body: plan.hasError
          ? Center(
              child: CbErrorState(
                message: errorMessageFor(plan.error!, context.l10n),
                traceId: traceIdOf(plan.error!),
                onRetry: () => ref.invalidate(carePlanProvider(planId)),
              ),
            )
          : const CbLoadingState.form(),
    );
  }
}

class _DoneForm extends ConsumerStatefulWidget {
  const _DoneForm({required this.plan});

  final CarePlan plan;

  @override
  ConsumerState<_DoneForm> createState() => _DoneFormState();
}

class _DoneFormState extends ConsumerState<_DoneForm> with OpenedInHousehold {
  // The server's limits.
  static const _maxProduct = 100;
  static const _maxManufacturer = 100;
  static const _maxBatch = 50;
  static const _maxClinic = 200;
  static const _maxVet = 100;
  static const _maxNotes = 2000;

  final _formKey = GlobalKey<FormState>();

  /// One id for this "Done", sent with every try. A retry after a lost
  /// response gets the first result back: the plan is never marked done
  /// twice.
  final _requestId = const Uuid().v4();
  var _performedOn = CbDateField.today();
  TimeOfDay? _time;

  /// Starts with the plan's usual product; what the field says is sent, so
  /// clearing it really means "no product".
  late final _product = TextEditingController(text: widget.plan.defaultProduct);
  final _manufacturer = TextEditingController();
  final _batch = TextEditingController();
  DateTime? _validFrom;
  DateTime? _validUntil;
  final _clinic = TextEditingController();
  final _vet = TextEditingController();
  final _notes = TextEditingController();

  /// The next date the user picked instead of the worked-out one.
  DateTime? _chosenNext;
  final _photos = <DraftPhoto>[];

  /// Set once "Done" went through. A retry then only attaches the photos
  /// that are left.
  ({CarePlan plan, CareRecord record})? _done;

  var _submitted = false;
  var _busy = false;

  /// While uploading: how many photos are done out of how many.
  (int, int)? _progress;
  var _serverErrors = <String, List<String>>{};
  String? _failure;

  CareKind get _kind => widget.plan.kind;

  /// The product fields are shown for kinds where something is given, and
  /// whenever the plan has a usual product, so it is never dropped unseen.
  bool get _showProduct =>
      usesProduct(_kind) || widget.plan.defaultProduct != null;

  /// Everything the form holds, to tell whether leaving loses anything.
  List<Object?> _values() => [
    _performedOn,
    _time,
    for (final field in [
      _product,
      _manufacturer,
      _batch,
      _clinic,
      _vet,
      _notes,
    ])
      field.text,
    _validFrom,
    _validUntil,
    _chosenNext,
    ..._photos,
    _photos.length,
  ];

  /// What the form opened with.
  late final List<Object?> _opened;

  /// Opened from an offline copy: doesn't save (see [openedFromCopy]).
  late final bool _fromCopy;

  @override
  void initState() {
    super.initState();
    _fromCopy = openedFromCopy(ref);
    _opened = _values();
  }

  @override
  void dispose() {
    for (final controller in [
      _product,
      _manufacturer,
      _batch,
      _clinic,
      _vet,
      _notes,
    ]) {
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
    r'^(performedOn|performedTime|product|manufacturer|batchNumber'
    r'|validFrom|validUntil|clinic|veterinarian|notes|nextDueOn)$',
  );

  /// The server refused a photo itself (too large, not a photo): saving
  /// again won't help until the user removes it.
  static bool _fileRefused(Object error) =>
      error is ApiException &&
      (error.kind == ApiErrorKind.payloadTooLarge ||
          error.kind == ApiErrorKind.unsupportedMediaType);

  /// The plan's next date after this "Done"; null when the plan finishes.
  DateTime? get _nextDue => nextDueAfterDone(
    interval: widget.plan.interval,
    performedOn: _performedOn,
    validUntil: usesTargets(_kind) ? _validUntil : null,
    chosen: _chosenNext,
  );

  Future<void> _addPhotos() async {
    final picked = await pickCarePhotos(context, ref.read(mediaPickerProvider));
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final media in picked) {
        if (_photos.length < CareRecord.maxFiles) {
          _photos.add(DraftPhoto.picked(media));
        }
      }
    });
  }

  Future<void> _chooseNext() async {
    final today = CbDateField.today();
    final initial = _nextDue ?? _performedOn;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(_performedOn) ? _performedOn : initial,
      // The server refuses a next date before this one.
      firstDate: _performedOn,
      lastDate: latestDueDate(today),
    );
    if (picked != null && mounted) setState(() => _chosenNext = picked);
  }

  CompletionInput _input() {
    String? clean(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    // Fields this kind doesn't have are not sent.
    final product = _showProduct;
    final validity = usesTargets(_kind);
    return CompletionInput(
      performedOn: _performedOn,
      performedTime: usesTime(_kind) ? _time : null,
      product: product ? clean(_product) : null,
      manufacturer: product ? clean(_manufacturer) : null,
      batchNumber: product ? clean(_batch) : null,
      validFrom: validity ? _validFrom : null,
      validUntil: validity ? _validUntil : null,
      clinic: clean(_clinic),
      veterinarian: clean(_vet),
      notes: clean(_notes),
      nextDueOn: _chosenNext,
    );
  }

  Future<void> _save() async {
    if (_fromCopy) {
      setState(() => _failure = context.l10n.formOpenedOffline);
      return;
    }
    if (_busy) return;
    final l10n = context.l10n;
    // Nothing can be typed while the screen saves (the fields are off).
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

    // Everything is read before the first await. Leaving the screen is
    // blocked while it saves (PopScope), but the app can still close it,
    // e.g. on sign-out, and the save must finish all the same.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final files = ref.read(filesRepositoryProvider);
    final care = ref.read(careRepositoryProvider);
    final plan = widget.plan;
    final input = _input();
    setState(() => _busy = true);
    try {
      // 1. Photos first: if one is refused (too large, wrong type), nothing
      //    is saved yet and the user can remove it.
      await uploadNewPhotos(
        files,
        _photos,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = (done, total));
        },
      );
      if (mounted) setState(() => _progress = null);

      // 2. "Done", once.
      var done = _done;
      if (done == null) {
        done = await care.completePlan(plan.id, input, requestId: _requestId);
        _done = done;
        container.read(appEventsProvider).action(AppAction.done);
        refreshCare(container, plan.petId, planId: plan.id);
      }

      // 3. Then the photos are attached to the new record, one by one.
      await attachNewPhotos(care, done.record.id, _photos);
      refreshCare(
        container,
        plan.petId,
        planId: plan.id,
        recordId: done.record.id,
      );
      if (mounted) navigator.pop();
      final next = done.plan.active ? done.plan.nextDueOn : null;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            next == null ? l10n.doneSavedFinished : l10n.doneSaved(next),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Marking the plan done failed: $error');
      // Part of it may have gone through, or all of it with only the answer
      // lost: the lists reload anyway, so going back shows the truth.
      final done = _done;
      refreshCare(
        container,
        plan.petId,
        planId: plan.id,
        recordId: done?.record.id,
      );
      if (isNotFound(error)) {
        // The plan (or the record "Done" made) was deleted elsewhere: there
        // is nothing left to save.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              done == null ? l10n.careGonePlan : l10n.careGoneRecord,
            ),
          ),
        );
        if (mounted) navigator.pop();
        return;
      }
      if (!mounted) return;
      final completed = done != null;
      // Field errors belong to "Done" itself; once it went through, only
      // the photos are left.
      final fieldErrors = completed
          ? const <String, List<String>>{}
          : fieldErrorsOf(error);
      final placed =
          fieldErrors.isNotEmpty &&
          fieldErrors.keys.every((key) => _fieldKeys.hasMatch(key));
      final String failure;
      if (completed && !_fileRefused(error)) {
        // Saving again attaches the photos that are left.
        failure = l10n.donePhotosFailed;
      } else if (placed) {
        failure = l10n.formCheckFields;
      } else {
        // Including a refused photo: the user has to remove it.
        failure = errorMessageFor(error, l10n);
      }
      setState(() {
        _progress = null;
        _serverErrors = {...fieldErrors};
        _failure = failure;
      });
      if (placed) revealTopmost(invalidFields(_formKey.currentState!));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = widget.plan;
    final progress = _progress;
    // While saving nothing changes; after "Done" went through only the
    // photos can.
    final editable = _done == null && !_busy;
    // Helpers mark plans done as they are: the server works out the next
    // date, and photos would need an upload helpers can't make.
    final canEdit = ref.watch(householdPermissionsProvider).canEdit;
    final petName = ref.watch(petProvider(plan.petId)).value?.name;
    final today = CbDateField.today();
    const gap = SizedBox(height: CbSpace.s4);

    return LeaveGuard(
      busy: _busy,
      changed: () => valuesChanged(_opened, _values()),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.doneTitle)),
        bottomNavigationBar: CbSaveBar(
          busy: _busy,
          error: _failure,
          busyLabel: progress == null
              ? null
              : l10n.uploadProgress(progress.$1 + 1, progress.$2),
          onSave: () => inOpenedHousehold(_save),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          // Not a lazy list: every field is built, so every field is checked.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s12,
            ),
            // No input while saving: a date picker opened now would outlive
            // the screen, and a change would come too late to be saved.
            child: IgnorePointer(
              ignoring: _busy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlanHeader(plan: plan, petName: petName),
                  const SizedBox(height: CbSpace.s6),
                  if (!editable) ...[
                    CbNotice(
                      key: const ValueKey('completed'),
                      message: l10n.doneCompletedNotice,
                    ),
                    gap,
                  ],
                  CbDateField(
                    key: const ValueKey('performedOn'),
                    label: l10n.donePerformedOnLabel,
                    value: _performedOn,
                    firstDate: earliestCareDate,
                    clearable: false,
                    enabled: editable,
                    onChanged: (date) => setState(() {
                      if (date == null) return;
                      _performedOn = date;
                      // A chosen next date can't be before this one.
                      final chosen = _chosenNext;
                      if (chosen != null && chosen.isBefore(date)) {
                        _chosenNext = null;
                      }
                    }),
                    validator: (_) => _serverError('performedOn'),
                  ),
                  if (usesTime(_kind)) ...[
                    gap,
                    CbTimeField(
                      key: const ValueKey('time'),
                      label: l10n.careTimeLabel,
                      helperText: l10n.careTimeHelper,
                      value: _time,
                      enabled: editable,
                      onChanged: (time) => setState(() => _time = time),
                      validator: (_) => _serverError('performedTime'),
                    ),
                  ],
                  if (_showProduct) ...[
                    gap,
                    CbTextField(
                      key: const ValueKey('product'),
                      label: l10n.careProductLabel,
                      controller: _product,
                      enabled: editable,
                      validator: (value) =>
                          _maxLength(value, _maxProduct) ??
                          _serverError('product'),
                    ),
                    gap,
                    CbTextField(
                      key: const ValueKey('manufacturer'),
                      label: l10n.careManufacturerLabel,
                      controller: _manufacturer,
                      enabled: editable,
                      validator: (value) =>
                          _maxLength(value, _maxManufacturer) ??
                          _serverError('manufacturer'),
                    ),
                    gap,
                    CbTextField(
                      key: const ValueKey('batch'),
                      label: l10n.careBatchLabel,
                      controller: _batch,
                      enabled: editable,
                      monospace: true,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) =>
                          _maxLength(value, _maxBatch) ??
                          _serverError('batchNumber'),
                    ),
                  ],
                  if (usesTargets(_kind)) ...[
                    // The server's rules: protection starts on or after the
                    // day it was given, and ends after that day and the start.
                    gap,
                    CbDateField(
                      key: const ValueKey('validFrom'),
                      label: l10n.careValidFromLabel,
                      value: _validFrom,
                      firstDate: _performedOn,
                      lastDate: latestDueDate(today),
                      enabled: editable,
                      onChanged: (date) => setState(() => _validFrom = date),
                      validator: (date) {
                        if (date != null && date.isBefore(_performedOn)) {
                          return l10n.recordValidFromInvalid;
                        }
                        return _serverError('validFrom');
                      },
                    ),
                    gap,
                    CbDateField(
                      key: const ValueKey('validUntil'),
                      label: l10n.careValidUntilLabel,
                      helperText: l10n.doneValidUntilHelper,
                      value: _validUntil,
                      firstDate: _performedOn,
                      lastDate: latestDueDate(today),
                      enabled: editable,
                      onChanged: (date) => setState(() => _validUntil = date),
                      validator: (date) {
                        final validFrom = _validFrom;
                        if (date != null &&
                            (!date.isAfter(_performedOn) ||
                                (validFrom != null &&
                                    date.isBefore(validFrom)))) {
                          return l10n.recordValidUntilInvalid;
                        }
                        return _serverError('validUntil');
                      },
                    ),
                  ],
                  gap,
                  CbTextField(
                    key: const ValueKey('clinic'),
                    label: l10n.careClinicLabel,
                    controller: _clinic,
                    enabled: editable,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        _maxLength(value, _maxClinic) ?? _serverError('clinic'),
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('vet'),
                    label: l10n.careVetLabel,
                    controller: _vet,
                    enabled: editable,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        _maxLength(value, _maxVet) ??
                        _serverError('veterinarian'),
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('notes'),
                    label: l10n.careNotesLabel,
                    controller: _notes,
                    enabled: editable,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) =>
                        _maxLength(value, _maxNotes) ?? _serverError('notes'),
                  ),
                  const SizedBox(height: CbSpace.s6),
                  _NextDate(
                    key: const ValueKey('next'),
                    plan: plan,
                    next: _nextDue,
                    chosen: _chosenNext != null,
                    fromValidUntil:
                        usesTargets(_kind) &&
                        _validUntil != null &&
                        plan.interval != null,
                    serverError: _serverError('nextDueOn'),
                    canChoose: canEdit,
                    onChange: editable ? _chooseNext : null,
                    onReset: editable && _chosenNext != null
                        ? () => setState(() => _chosenNext = null)
                        : null,
                  ),
                  if (canEdit) ...[
                    const SizedBox(height: CbSpace.s6),
                    PhotosField(
                      key: const ValueKey('photos'),
                      photos: _photos,
                      enabled: !_busy,
                      onAdd: _addPhotos,
                      // Photos already attached stay: they are on the record.
                      canRemove: (photo) => !photo.attached,
                      onRemove: (photo) =>
                          setState(() => _photos.remove(photo)),
                      errorText: _serverError('fileIds'),
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

/// What is being marked done: the plan, the pet and when it was due.
class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan, required this.petName});

  final CarePlan plan;
  final String? petName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final petName = this.petName;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KindIcon(kind: plan.kind),
        const SizedBox(width: CbSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.title, style: text.title),
              const SizedBox(height: CbSpace.s1),
              Text(
                [?petName, planIntervalLabel(l10n, plan)].join(' · '),
                style: text.bodySm.copyWith(color: context.cb.inkMuted),
              ),
              const SizedBox(height: CbSpace.s1),
              DueLine(
                status: plan.status,
                daysLeft: plan.daysLeft,
                dueOn: plan.nextDueOn,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The plan's next date after this "Done", how it was worked out, and
/// buttons to choose another date or go back to the worked-out one.
class _NextDate extends StatelessWidget {
  const _NextDate({
    super.key,
    required this.plan,
    required this.next,
    required this.chosen,
    required this.fromValidUntil,
    required this.onChange,
    required this.onReset,
    this.serverError,
    this.canChoose = true,
  });

  final CarePlan plan;

  /// Null when the plan finishes (a one-off) or can't be worked out here.
  final DateTime? next;
  final bool chosen;
  final bool fromValidUntil;
  final VoidCallback? onChange;
  final VoidCallback? onReset;
  final String? serverError;

  /// "Change": not for helpers, whose "Done" takes the worked-out date.
  final bool canChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final next = this.next;
    final serverError = this.serverError;
    final String explanation;
    if (chosen) {
      explanation = l10n.doneNextChosen;
    } else if (plan.intervalUnknown) {
      explanation = l10n.doneNextUnknown;
    } else if (next == null) {
      explanation = l10n.doneNextFinished;
    } else if (fromValidUntil) {
      explanation = l10n.doneNextFromValidUntil;
    } else {
      explanation = l10n.doneNextFromInterval(planIntervalLabel(l10n, plan));
    }

    return CbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The texts are one node for screen readers; the buttons stay
          // their own.
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.doneNextTitle, style: text.label),
                const SizedBox(height: CbSpace.s2),
                if (next != null)
                  Text(l10n.dateMedium(next), style: text.subtitle),
                Text(
                  explanation,
                  style: text.bodySm.copyWith(color: cb.inkMuted),
                ),
                if (serverError != null)
                  Text(
                    serverError,
                    style: text.caption.copyWith(color: cb.danger),
                  ),
              ],
            ),
          ),
          if (canChoose) ...[
            const SizedBox(height: CbSpace.s2),
            // In line with the date above; 16 apart, as they have no
            // padding of their own.
            Wrap(
              spacing: CbSpace.s4,
              children: [
                TextButton(
                  style: cbInlineTextButtonStyle,
                  onPressed: onChange,
                  child: Text(l10n.doneNextChange),
                ),
                if (chosen)
                  TextButton(
                    style: cbInlineTextButtonStyle,
                    onPressed: onReset,
                    child: Text(l10n.doneNextReset),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
