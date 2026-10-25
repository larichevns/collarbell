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
import '../../theme/collarbell_theme.dart';
import '../files/files_repository.dart';
import '../files/media_picker.dart';
import '../household/current_household.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import 'care.dart';
import 'care_labels.dart';
import 'care_refresh.dart';
import 'care_repository.dart';
import 'care_rules.dart';
import 'widgets/kind_dropdown.dart';
import 'widgets/record_photos.dart';
import 'widgets/target_chips.dart';

/// Adds a record to the pet [petId] by hand, e.g. history from the paper
/// passport, starting with [kind] (and [target]); or edits the record
/// [recordId]. Records don't move plans: only "Done" does.
class RecordFormScreen extends ConsumerWidget {
  const RecordFormScreen({
    super.key,
    required this.petId,
    this.recordId,
    this.kind,
    this.target,
  });

  final String petId;

  /// Null when adding a record.
  final String? recordId;

  /// What a new record starts as; a vaccination when null.
  final CareKind? kind;

  /// A vaccine target a new record starts with, e.g. rabies for the
  /// passport's rabies section.
  final VaccineTarget? target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recordId = this.recordId;
    final pet = ref.watch(petProvider(petId));
    final record = recordId == null
        ? null
        : ref.watch(careRecordProvider(recordId));
    final petValue = pet.value;
    final recordValue = record?.value;
    final title = recordId == null
        ? l10n.recordFormAddTitle
        : l10n.recordFormEditTitle;

    if (petValue != null && (record == null || recordValue != null)) {
      if (recordValue != null && recordValue.hasUnknownValues) {
        // Saving would replace values this app can't show.
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Padding(
            padding: const EdgeInsets.all(CbSpace.s4),
            child: CbNotice(message: l10n.recordReadOnly),
          ),
        );
      }
      final startKind = recordValue?.kind ?? kind ?? CareKind.vaccination;
      final startTargets = recordValue?.targets ?? [?target];
      return _RecordForm(
        pet: petValue,
        record: recordValue,
        kind: startKind,
        targets: startTargets,
        defaultTitle: defaultRecordTitle(l10n, startKind, startTargets),
      );
    }

    final error = pet.error ?? record?.error;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: error != null
          ? Center(
              child: CbErrorState(
                message: errorMessageFor(error, l10n),
                traceId: traceIdOf(error),
                onRetry: () {
                  ref.invalidate(petProvider(petId));
                  if (recordId != null) {
                    ref.invalidate(careRecordProvider(recordId));
                  }
                },
              ),
            )
          : const CbLoadingState.form(),
    );
  }
}

class _RecordForm extends ConsumerStatefulWidget {
  const _RecordForm({
    required this.pet,
    required this.record,
    required this.kind,
    required this.targets,
    required this.defaultTitle,
  });

  final Pet pet;

  /// The record being edited, or null when adding one.
  final CareRecord? record;
  final CareKind kind;
  final List<VaccineTarget> targets;

  /// The title a new record starts with, e.g. "Rabies".
  final String defaultTitle;

  @override
  ConsumerState<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends ConsumerState<_RecordForm>
    with OpenedInHousehold {
  // The server's limits; checked here so mistakes show before saving.
  static const _maxTitle = 100;
  static const _maxProduct = 100;
  static const _maxManufacturer = 100;
  static const _maxBatch = 50;
  static const _maxLaboratory = 200;
  static const _maxReportNumber = 50;
  static const _maxTiter = 1000.0;
  static const _maxWeight = 200.0;
  static const _maxClinic = 200;
  static const _maxVet = 100;
  static const _maxNotes = 2000;

  final _formKey = GlobalKey<FormState>();
  final _photosKey = GlobalKey();
  late var _kind = widget.kind;
  late final _title = TextEditingController(
    text: widget.record?.title ?? widget.defaultTitle,
  );
  late DateTime? _performedOn =
      widget.record?.performedOn ?? CbDateField.today();
  late TimeOfDay? _time = widget.record?.performedTime;
  late var _targets = widget.targets;
  late final _product = TextEditingController(text: widget.record?.product);
  late final _manufacturer = TextEditingController(
    text: widget.record?.manufacturer,
  );
  late final _batch = TextEditingController(text: widget.record?.batchNumber);
  late DateTime? _validFrom = widget.record?.validFrom;
  late DateTime? _validUntil = widget.record?.validUntil;
  late final _laboratory = TextEditingController(
    text: widget.record?.details.laboratory,
  );
  late final _reportNumber = TextEditingController(
    text: widget.record?.details.reportNumber,
  );
  late var _fitForTravel = widget.record?.details.fitForTravel ?? false;
  late final _clinic = TextEditingController(text: widget.record?.clinic);
  late final _vet = TextEditingController(text: widget.record?.veterinarian);
  late final _notes = TextEditingController(text: widget.record?.notes);

  // Numbers are shown with the user's decimal separator ("2,5" in
  // Russian), which needs the locale: didChangeDependencies fills them in.
  final _titer = TextEditingController();
  final _weight = TextEditingController();
  var _numbersFilled = false;

  late final _photos = [
    for (final file in widget.record?.files ?? const []) DraftPhoto.saved(file),
  ];

  /// Saved photos the user removed; they are deleted one by one on save.
  /// Photos the form doesn't know about (added elsewhere meanwhile) are
  /// never touched.
  final _removedFileIds = <String>{};

  /// One id for adding this record, sent with every try. A retry after a
  /// lost response gets the record that was added, not a second one.
  final _requestId = const Uuid().v4();

  /// The record this form created. A retry after a failed save (say, a
  /// photo didn't attach) updates it instead of adding a second record.
  CareRecord? _created;

  var _submitted = false;
  var _busy = false;
  (int, int)? _progress;
  var _serverErrors = <String, List<String>>{};
  String? _failure;

  CareRecord? get _record => widget.record;
  CareRecordDetails get _details =>
      widget.record?.details ?? CareRecordDetails.empty;

  // A field is shown when it belongs to the kind, and whenever the record
  // already has a value in it, so saving never drops a value unseen.
  bool get _showTime => usesTime(_kind) || _record?.performedTime != null;
  bool get _showProduct =>
      usesProduct(_kind) ||
      _record?.product != null ||
      _record?.manufacturer != null ||
      _record?.batchNumber != null;
  bool get _showValidity =>
      usesTargets(_kind) ||
      _record?.validFrom != null ||
      _record?.validUntil != null;
  bool get _showTiter =>
      usesTiter(_kind) ||
      _details.laboratory != null ||
      _details.reportNumber != null ||
      _details.titerIuPerMl != null;
  bool get _showExam =>
      usesExam(_kind) ||
      _record?.weightKg != null ||
      _details.fitForTravel != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_numbersFilled) return;
    _numbersFilled = true;
    final l10n = context.l10n;
    final titer = _details.titerIuPerMl;
    final weight = _record?.weightKg;
    if (titer != null) _titer.text = formatDecimal(l10n, titer);
    if (weight != null) _weight.text = formatDecimal(l10n, weight);
    // Only now is everything in place: what leaving compares against.
    _opened = _values();
  }

  /// Everything the form holds, to tell whether leaving loses anything.
  List<Object?> _values() => [
    _kind,
    _performedOn,
    _time,
    // The chips give the targets back in their own order: compared as a set.
    ...(_targets.map((target) => target.index).toList()..sort()),
    _targets.length,
    for (final field in [
      _title,
      _product,
      _manufacturer,
      _batch,
      _laboratory,
      _reportNumber,
      _clinic,
      _vet,
      _notes,
      _titer,
      _weight,
    ])
      field.text,
    _validFrom,
    _validUntil,
    _fitForTravel,
    ..._photos,
    _photos.length,
    _removedFileIds.length,
  ];

  /// What the form opened with.
  late final List<Object?> _opened;

  /// Opened from an offline copy: doesn't save (see [openedFromCopy]).
  late final bool _fromCopy;

  @override
  void initState() {
    super.initState();
    _fromCopy = widget.record != null && openedFromCopy(ref);
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _product,
      _manufacturer,
      _batch,
      _laboratory,
      _reportNumber,
      _titer,
      _weight,
      _clinic,
      _vet,
      _notes,
    ]) {
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

  String? _validateTitle(String? value) {
    if ((value ?? '').trim().isEmpty) return context.l10n.recordTitleRequired;
    return _maxLength(value, _maxTitle) ?? _serverError('title');
  }

  /// An empty number is fine; anything else has to be a number in range.
  String? _validateNumber(
    String? value, {
    required bool Function(double number) inRange,
    required String message,
    required String field,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return _serverError(field);
    final number = parseDecimal(text);
    if (number == null || !inRange(number)) return message;
    return _serverError(field);
  }

  String? get _photosError {
    if (_photos.length > CareRecord.maxFiles) {
      return context.l10n.carePhotosTooMany(CareRecord.maxFiles);
    }
    return _serverError('fileIds');
  }

  static final _fieldKeys = RegExp(
    r'^(kind|title|performedOn|performedTime|product|manufacturer|batchNumber'
    r'|validFrom|validUntil|targets|clinic|veterinarian|weightKg|notes'
    r'|details\.(laboratory|reportNumber|titerIuPerMl)|fileIds)$',
  );

  /// Validates all fields and the photos, and scrolls to the first problem.
  bool _validateAndReveal() {
    final invalid = invalidFields(_formKey.currentState!);
    final photos = _photosKey.currentContext;
    if (_photosError != null && photos != null) invalid.add(photos);
    revealTopmost(invalid);
    return invalid.isEmpty;
  }

  // --- Actions ----------------------------------------------------------

  void _changeKind(CareKind kind) {
    final l10n = context.l10n;
    setState(() {
      // A new record's title follows the kind until the user types one.
      final oldDefault = defaultRecordTitle(l10n, _kind, _targets);
      final title = _title.text.trim();
      if (_record == null && (title.isEmpty || title == oldDefault)) {
        _title.text = defaultRecordTitle(
          l10n,
          kind,
          usesTargets(kind) ? _targets : const [],
        );
      }
      _kind = kind;
    });
  }

  Future<void> _addPhotos() async {
    final picked = await pickCarePhotos(context, ref.read(mediaPickerProvider));
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final media in picked) {
        if (_photos.length < CareRecord.maxFiles) {
          _photos.add(DraftPhoto.picked(media));
        }
      }
      _serverErrors.remove('fileIds');
    });
  }

  void _removePhoto(DraftPhoto photo) {
    setState(() {
      _photos.remove(photo);
      final file = photo.file;
      if (photo.attached && file != null) _removedFileIds.add(file.id);
    });
  }

  CareRecordInput _input() {
    String? clean(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    // Fields that aren't shown are not sent (see the _show getters).
    final product = _showProduct;
    final titer = _showTiter;
    final exam = _showExam;
    final validity = _showValidity;
    return CareRecordInput(
      kind: _kind,
      title: _title.text.trim(),
      performedOn: _performedOn!,
      performedTime: _showTime ? _time : null,
      product: product ? clean(_product) : null,
      manufacturer: product ? clean(_manufacturer) : null,
      batchNumber: product ? clean(_batch) : null,
      validFrom: validity ? _validFrom : null,
      validUntil: validity ? _validUntil : null,
      targets: usesTargets(_kind) ? _targets : const [],
      clinic: clean(_clinic),
      veterinarian: clean(_vet),
      weightKg: exam ? parseDecimal(_weight.text) : null,
      details: CareRecordDetails(
        laboratory: titer ? clean(_laboratory) : null,
        reportNumber: titer ? clean(_reportNumber) : null,
        titerIuPerMl: titer ? parseDecimal(_titer.text) : null,
        // A switch can't say "not stated": switched off, a record that
        // never said stays silent instead of becoming "not fit".
        fitForTravel: !exam
            ? null
            : _fitForTravel
            ? true
            : (_details.fitForTravel == false ? false : null),
      ),
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
    // Nothing can be typed while the form saves (see IgnorePointer below).
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitted = true;
      _serverErrors = {};
      _failure = null;
    });
    if (!_validateAndReveal()) {
      setState(() => _failure = l10n.formCheckFields);
      return;
    }

    // Everything is read before the first await. Leaving the form is
    // blocked while it saves (PopScope), but the app can still close it,
    // e.g. on sign-out, and the save must finish all the same.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final files = ref.read(filesRepositoryProvider);
    final care = ref.read(careRepositoryProvider);
    final petId = widget.pet.id;
    final input = _input();
    CareRecord? saved;
    setState(() => _busy = true);
    try {
      // Upload first: if a photo is refused (too large, wrong type),
      // nothing is saved yet and the user can remove it.
      await uploadNewPhotos(
        files,
        _photos,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = (done, total));
        },
      );
      if (mounted) setState(() => _progress = null);

      final existing = _record ?? _created;
      if (existing == null) {
        saved = await care.createRecord(petId, input, requestId: _requestId);
        _created = saved;
      } else {
        saved = await care.updateRecord(existing.id, input);
      }

      // Photos change one by one; a list never replaces the record's
      // photos. Removed ones go first: a full record (10 photos) can then
      // swap one. Removing the last photo doesn't delete the record.
      for (final fileId in [..._removedFileIds]) {
        await care.removeRecordFile(saved.id, fileId);
        _removedFileIds.remove(fileId);
      }
      await attachNewPhotos(care, saved.id, _photos);
      refreshCare(container, petId, recordId: saved.id);
      if (mounted) navigator.pop();
    } catch (error) {
      debugPrint('Saving the record failed: $error');
      // Part of the save may have gone through, or all of it with only the
      // answer lost: the lists reload anyway, so going back shows the truth.
      final known = _record ?? _created;
      refreshCare(container, petId, recordId: known?.id);
      if (isNotFound(error)) {
        // The record (or, when adding, the pet) was deleted elsewhere:
        // there is nothing left to save.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              known == null ? l10n.careGonePet : l10n.careGoneRecord,
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
        _progress = null;
        _serverErrors = {...fieldErrors};
        _failure = saved != null
            // The record is saved; only a photo step failed.
            ? l10n.recordPhotosFailed
            : placed
            ? l10n.formCheckFields
            : errorMessageFor(error, l10n);
      });
      if (placed) _validateAndReveal();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Layout -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final progress = _progress;
    final today = CbDateField.today();
    const gap = SizedBox(height: CbSpace.s4);

    return LeaveGuard(
      busy: _busy,
      changed: () => valuesChanged(_opened, _values()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _record == null
                ? l10n.recordFormAddTitle
                : l10n.recordFormEditTitle,
          ),
        ),
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
          // Every field has its own key: rows that come and go with the kind
          // must not hand a field's text or error to another field.
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
                  CbLabeled(
                    key: const ValueKey('kind'),
                    label: l10n.careKindLabel,
                    child: KindDropdown(
                      value: _kind,
                      validator: (_) => _serverError('kind'),
                      onChanged: _changeKind,
                    ),
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('title'),
                    label: l10n.recordTitleLabel,
                    hintText: l10n.recordTitleHint,
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    validator: _validateTitle,
                  ),
                  gap,
                  CbDateField(
                    key: const ValueKey('performedOn'),
                    label: l10n.recordPerformedOnLabel,
                    value: _performedOn,
                    firstDate: earliestCareDate,
                    clearable: false,
                    onChanged: (date) => setState(() => _performedOn = date),
                    validator: (date) => date == null
                        ? l10n.dateRequired
                        : _serverError('performedOn'),
                  ),
                  if (_showTime) ...[
                    gap,
                    CbTimeField(
                      key: const ValueKey('time'),
                      label: l10n.careTimeLabel,
                      helperText: l10n.careTimeHelper,
                      value: _time,
                      onChanged: (time) => setState(() => _time = time),
                      validator: (_) => _serverError('performedTime'),
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
                  if (_showProduct) ...[
                    gap,
                    CbTextField(
                      key: const ValueKey('product'),
                      label: l10n.careProductLabel,
                      controller: _product,
                      validator: (value) =>
                          _maxLength(value, _maxProduct) ??
                          _serverError('product'),
                    ),
                    gap,
                    CbTextField(
                      key: const ValueKey('manufacturer'),
                      label: l10n.careManufacturerLabel,
                      controller: _manufacturer,
                      validator: (value) =>
                          _maxLength(value, _maxManufacturer) ??
                          _serverError('manufacturer'),
                    ),
                    gap,
                    CbTextField(
                      key: const ValueKey('batch'),
                      label: l10n.careBatchLabel,
                      controller: _batch,
                      monospace: true,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) =>
                          _maxLength(value, _maxBatch) ??
                          _serverError('batchNumber'),
                    ),
                  ],
                  if (_showValidity) ...[
                    gap,
                    CbDateField(
                      key: const ValueKey('validFrom'),
                      label: l10n.careValidFromLabel,
                      value: _validFrom,
                      firstDate: earliestCareDate,
                      lastDate: latestDueDate(today),
                      onChanged: (date) => setState(() => _validFrom = date),
                      validator: (date) {
                        final performedOn = _performedOn;
                        if (date != null &&
                            performedOn != null &&
                            date.isBefore(performedOn)) {
                          return l10n.recordValidFromInvalid;
                        }
                        return _serverError('validFrom');
                      },
                    ),
                    gap,
                    CbDateField(
                      key: const ValueKey('validUntil'),
                      label: l10n.careValidUntilLabel,
                      value: _validUntil,
                      firstDate: earliestCareDate,
                      lastDate: latestDueDate(today),
                      onChanged: (date) => setState(() => _validUntil = date),
                      validator: (date) {
                        final performedOn = _performedOn;
                        final validFrom = _validFrom;
                        if (date != null &&
                            ((performedOn != null &&
                                    !date.isAfter(performedOn)) ||
                                (validFrom != null &&
                                    date.isBefore(validFrom)))) {
                          return l10n.recordValidUntilInvalid;
                        }
                        return _serverError('validUntil');
                      },
                    ),
                  ],
                  if (_showTiter) ...[
                    gap,
                    CbTextField(
                      key: const ValueKey('laboratory'),
                      label: l10n.recordLaboratoryLabel,
                      controller: _laboratory,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          _maxLength(value, _maxLaboratory) ??
                          _serverError('details.laboratory'),
                    ),
                    gap,
                    CbTextField(
                      key: const ValueKey('reportNumber'),
                      label: l10n.recordReportNumberLabel,
                      controller: _reportNumber,
                      monospace: true,
                      autocorrect: false,
                      validator: (value) =>
                          _maxLength(value, _maxReportNumber) ??
                          _serverError('details.reportNumber'),
                    ),
                    gap,
                    CbTextField(
                      key: const ValueKey('titer'),
                      label: l10n.recordTiterLabel,
                      helperText: l10n.recordTiterHelper,
                      controller: _titer,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) => _validateNumber(
                        value,
                        inRange: (number) => number >= 0 && number <= _maxTiter,
                        message: l10n.recordTiterInvalid,
                        field: 'details.titerIuPerMl',
                      ),
                    ),
                  ],
                  if (_showExam) ...[
                    gap,
                    CbTextField(
                      key: const ValueKey('weight'),
                      label: l10n.recordWeightLabel,
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) => _validateNumber(
                        value,
                        inRange: (number) => number > 0 && number <= _maxWeight,
                        message: l10n.recordWeightInvalid,
                        field: 'weightKg',
                      ),
                    ),
                    SwitchListTile(
                      key: const ValueKey('fitForTravel'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.recordFitForTravel, style: text.body),
                      value: _fitForTravel,
                      onChanged: (value) =>
                          setState(() => _fitForTravel = value),
                    ),
                  ],
                  gap,
                  CbTextField(
                    key: const ValueKey('clinic'),
                    label: l10n.careClinicLabel,
                    controller: _clinic,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        _maxLength(value, _maxClinic) ?? _serverError('clinic'),
                  ),
                  gap,
                  CbTextField(
                    key: const ValueKey('vet'),
                    label: l10n.careVetLabel,
                    controller: _vet,
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
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) =>
                        _maxLength(value, _maxNotes) ?? _serverError('notes'),
                  ),
                  const SizedBox(height: CbSpace.s8),
                  PhotosField(
                    key: _photosKey,
                    photos: _photos,
                    enabled: !_busy,
                    onAdd: _addPhotos,
                    onRemove: _removePhoto,
                    errorText: _photosError,
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
