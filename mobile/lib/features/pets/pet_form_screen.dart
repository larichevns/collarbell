import 'dart:io' show File;

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/offline_copy.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/form_errors.dart';
import '../../shared/widgets/leave_guard.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../ai/ai_repository.dart';
import '../files/files_repository.dart';
import '../files/media_picker.dart';
import '../files/stored_file.dart';
import '../files/widgets/media_sheet.dart';
import '../household/current_household.dart';
import '../supplies/supply_refresh.dart';
import '../today/today_repository.dart';
import 'chip_reader.dart';
import 'identifier_rules.dart';
import 'pet.dart';
import 'pet_labels.dart';
import 'pets_repository.dart';
import 'widgets/identifier_editor.dart';
import 'widgets/pet_avatar.dart';

/// Adds a pet, or edits the pet [petId].
class PetFormScreen extends ConsumerWidget {
  const PetFormScreen({super.key, this.petId});

  /// Null when adding a pet.
  final String? petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petId = this.petId;
    if (petId == null) return const _PetForm(pet: null);

    final pet = ref.watch(petProvider(petId));
    final value = pet.value;
    if (value != null) return _PetForm(pet: value);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.petFormEditTitle)),
      body: pet.hasError
          ? Center(
              child: CbErrorState(
                message: errorMessageFor(pet.error!, context.l10n),
                traceId: traceIdOf(pet.error!),
                onRetry: () => ref.invalidate(petProvider(petId)),
              ),
            )
          : const CbLoadingState.form(),
    );
  }
}

class _PetForm extends ConsumerStatefulWidget {
  const _PetForm({required this.pet});

  /// The pet being edited, or null when adding one.
  final Pet? pet;

  @override
  ConsumerState<_PetForm> createState() => _PetFormState();
}

class _PetFormState extends ConsumerState<_PetForm> with OpenedInHousehold {
  // The server's limits; checked here so mistakes show before saving.
  static const _maxName = 60;
  static const _maxBreed = 100;
  static const _maxColor = 60;
  static const _maxMarkings = 300;
  static const _maxAllergies = 500;
  static const _maxNotes = 2000;

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pet?.name);
  late final _breed = TextEditingController(text: widget.pet?.breed);
  late final _color = TextEditingController(text: widget.pet?.color);
  late final _markings = TextEditingController(text: widget.pet?.markings);
  late final _allergies = TextEditingController(text: widget.pet?.allergies);
  late final _notes = TextEditingController(text: widget.pet?.notes);

  late var _species = widget.pet?.species ?? PetSpecies.cat;
  late var _sex = widget.pet?.sex ?? PetSex.unknown;
  late var _birthDate = widget.pet?.birthDate;
  late var _birthDateApproximate = widget.pet?.birthDateApproximate ?? false;
  late var _neutered = widget.pet?.neutered ?? false;
  late var _neuteredOn = widget.pet?.neuteredOn;
  late final _identifiers = [
    for (final identifier in widget.pet?.identifiers ?? const <PetIdentifier>[])
      IdentifierDraft.fromIdentifier(identifier),
  ];

  /// A new photo to upload on save.
  PickedMedia? _newPhoto;

  /// [_newPhoto] once uploaded: a retry after a failed save reuses it
  /// instead of uploading it again.
  StoredFile? _uploadedPhoto;

  /// The user removed the current photo.
  var _removePhoto = false;

  var _submitted = false;
  var _busy = false;
  var _uploadingPhoto = false;

  /// A chip scan is under way: a second tap doesn't open a second scanner.
  var _scanning = false;

  /// Field errors of the last 400 response, by API field name.
  var _serverErrors = <String, List<String>>{};

  /// A failure that doesn't belong to one field.
  String? _failure;

  bool get _isEdit => widget.pet != null;

  /// Everything the form holds, to tell whether leaving loses anything.
  List<Object?> _values() => [
    for (final field in [_name, _breed, _color, _markings, _allergies, _notes])
      field.text,
    _species,
    _sex,
    _birthDate,
    _birthDateApproximate,
    _neutered,
    _neuteredOn,
    for (final draft in _identifiers) ...[
      draft.type,
      draft.code.text,
      draft.appliedOn,
      draft.location.text,
    ],
    _identifiers.length,
    _newPhoto,
    _removePhoto,
  ];

  /// What the form opened with.
  late final List<Object?> _opened;

  /// Opened from an offline copy: doesn't save (see [openedFromCopy]).
  late final bool _fromCopy;

  @override
  void initState() {
    super.initState();
    _fromCopy = widget.pet != null && openedFromCopy(ref);
    _opened = _values();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _breed,
      _color,
      _markings,
      _allergies,
      _notes,
    ]) {
      controller.dispose();
    }
    for (final draft in _identifiers) {
      draft.dispose();
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

  String? _validateName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return context.l10n.petNameRequired;
    return _maxLength(name, _maxName) ?? _serverError('name');
  }

  String? _validateIdentifierCode(IdentifierDraft draft) {
    final l10n = context.l10n;
    final index = _identifiers.indexOf(draft);
    // A card that was just removed is validated once more as it leaves.
    if (index < 0) return null;
    final problem = IdentifierRules.check(
      draft.type,
      draft.code.text,
      // Only earlier cards: the second of two equal codes gets the error.
      otherCodes: [
        for (final other in _identifiers.take(index))
          IdentifierRules.normalize(other.code.text),
      ],
    );
    return problem == null
        ? _serverError('identifiers[$index].code')
        : identifierProblemLabel(l10n, problem);
  }

  /// The server's error for one field of [draft]'s card, e.g. "code".
  String? _identifierFieldError(IdentifierDraft draft, String field) {
    final index = _identifiers.indexOf(draft);
    return index < 0 ? null : _serverError('identifiers[$index].$field');
  }

  /// Server error keys this form shows on a field; others go to the banner.
  static final _fieldKeys = RegExp(
    r'^(name|breed|birthDate|neuteredOn|color|markings|allergies|notes'
    r'|identifiers|identifiers\[\d+\]\.(code|appliedOn|location))$',
  );

  // --- Actions ----------------------------------------------------------

  Future<void> _choosePhoto() async {
    final hasPhoto =
        _newPhoto != null || (widget.pet?.photo != null && !_removePhoto);
    final action = await showMediaActionSheet(
      context,
      actions: [
        MediaAction.camera,
        MediaAction.library,
        if (hasPhoto) MediaAction.remove,
      ],
    );
    if (action == null || !mounted) return;
    if (action == MediaAction.remove) {
      setState(() {
        _newPhoto = null;
        _uploadedPhoto = null;
        _removePhoto = true;
      });
      return;
    }
    final picker = ref.read(mediaPickerProvider);
    try {
      final photo = action == MediaAction.camera
          ? await picker.takePhoto()
          : await picker.pickPhoto();
      if (photo != null && mounted) {
        setState(() {
          _newPhoto = photo;
          _uploadedPhoto = null;
        });
      }
    } catch (error) {
      debugPrint('Picking a photo failed: $error');
      if (mounted) showPickerError(context);
    }
  }

  void _addIdentifier() {
    setState(() {
      _identifiers.add(IdentifierDraft());
      _clearIdentifierErrors();
    });
  }

  void _removeIdentifier(IdentifierDraft draft) {
    setState(() {
      _identifiers.remove(draft);
      _clearIdentifierErrors();
    });
    // Its text fields still use the controllers until this frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
  }

  /// Server errors name identifiers by position, which a change of the list
  /// makes wrong.
  void _clearIdentifierErrors() {
    _serverErrors = {
      for (final entry in _serverErrors.entries)
        if (!entry.key.startsWith('identifiers')) entry.key: entry.value,
    };
  }

  /// Scans the microchip number into [draft]'s card: a barcode fills it at
  /// once, a photo without one is read by AI.
  Future<void> _scanChip(IdentifierDraft draft) async {
    if (_scanning) return;
    _scanning = true;
    try {
      final picker = ref.read(mediaPickerProvider);
      if (draft.scanNote != null) setState(() => draft.scanNote = null);
      final scan = await ref.read(chipReaderProvider).read(context);
      // While the scanner was open, the card may have gone (removed, or the
      // form closed).
      final cardThere = mounted && _identifiers.contains(draft);
      switch (scan) {
        case null:
          return;
        case ChipBarcode(:final type, :final code):
          if (cardThere) _fillIdentifier(draft, type: type, code: code);
        case ChipPhoto(:final photo) when !cardThere:
          await picker.deletePicked([photo]);
        case ChipPhoto(:final photo):
          await _readChipPhoto(draft, photo);
      }
    } finally {
      _scanning = false;
    }
  }

  /// Has AI read the [photo] the phone found no barcode in, and fills
  /// [draft]'s card with the number it read.
  Future<void> _readChipPhoto(IdentifierDraft draft, PickedMedia photo) async {
    final l10n = context.l10n;
    final picker = ref.read(mediaPickerProvider);
    final files = ref.read(filesRepositoryProvider);
    final pets = ref.read(petsRepositoryProvider);

    // Known to have no AI: nothing else can read the photo.
    if (ref.read(aiStatusProvider).value?.configured == false) {
      await picker.deletePicked([photo]);
      _noteOnCard(draft, l10n.chipScanNoAi, failed: true);
      return;
    }

    // "Cancel" stops the photo on its way: before AI gets it, or while AI
    // reads it.
    final cancel = CancelToken();

    // Never throws: how it ended is the answer, so a failure before the
    // dialog listens isn't lost.
    Future<AsyncResult<List<IdentifierReading>>> read() async {
      try {
        final String fileId;
        try {
          fileId = (await files.upload(photo)).id;
        } finally {
          // A passport page is personal: once uploaded (or refused), it
          // doesn't stay on the phone.
          await picker.deletePicked([photo]);
        }
        if (cancel.isCancelled) return const AsyncData([]);
        return AsyncData(
          await pets.scanIdentifiers([fileId], cancelToken: cancel),
        );
      } catch (error, stackTrace) {
        return AsyncError(error, stackTrace);
      }
    }

    ref.read(appEventsProvider).action(AppAction.scanStarted);
    final reading = read();
    final outcome = await showDialog<AsyncResult<List<IdentifierReading>>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChipReadingDialog(reading: reading),
    );
    switch (outcome) {
      case null:
        cancel.cancel();
      case AsyncData(:final value):
        await _useReadings(draft, value);
      case AsyncError(:final error):
        debugPrint('Reading the chip photo failed: $error');
        final message = switch (error) {
          IdentifierScanFailed(problem: IdentifierScanProblem.busy) =>
            l10n.chipScanBusy,
          IdentifierScanFailed(problem: IdentifierScanProblem.notConfigured) =>
            l10n.chipScanNoAi,
          IdentifierScanFailed(problem: IdentifierScanProblem.rejected) =>
            l10n.chipScanRejected,
          _ => errorMessageFor(error, l10n),
        };
        _noteOnCard(draft, message, failed: true);
    }
  }

  /// One number fills the card; of several, the user picks one; without any,
  /// the card says so. What AI read needs a look at the paper: the card asks
  /// for it.
  Future<void> _useReadings(
    IdentifierDraft draft,
    List<IdentifierReading> readings,
  ) async {
    if (!mounted || !_identifiers.contains(draft)) return;
    final l10n = context.l10n;
    if (readings.isEmpty) {
      _noteOnCard(draft, l10n.chipScanNothingFound);
      return;
    }
    final reading = readings.length == 1
        ? readings.single
        : await pickIdentifierReading(
            context,
            readings,
            otherCodes: [
              for (final other in _identifiers)
                if (other != draft) IdentifierRules.normalize(other.code.text),
            ],
          );
    if (reading == null || !mounted || !_identifiers.contains(draft)) return;
    _fillIdentifier(
      draft,
      type: reading.type,
      code: reading.rawCode,
      location: reading.location,
      appliedOn: reading.appliedOn,
      note: l10n.chipScanCheck,
    );
  }

  /// Puts a scanned number into [draft]'s card with its type. The scanned
  /// place and date go where the card has none yet, or where they belonged
  /// to another number the scan replaces; typed for this number, they stay.
  void _fillIdentifier(
    IdentifierDraft draft, {
    required IdentifierType type,
    required String code,
    String? location,
    DateTime? appliedOn,
    String? note,
  }) {
    final before = IdentifierRules.normalize(draft.code.text);
    final replaced =
        before.isNotEmpty && before != IdentifierRules.normalize(code);
    draft.code.text = code;
    if (location != null && (replaced || draft.location.text.trim().isEmpty)) {
      draft.location.text = location;
    }
    setState(() {
      draft.type = type;
      if (appliedOn != null && (replaced || draft.appliedOn == null)) {
        draft.appliedOn = appliedOn;
      }
      draft.scanNote = note == null ? null : (text: note, failed: false);
    });
  }

  /// Says on [draft]'s card how its scan went, while the card is there.
  void _noteOnCard(IdentifierDraft draft, String text, {bool failed = false}) {
    if (!mounted || !_identifiers.contains(draft)) return;
    setState(() => draft.scanNote = (text: text, failed: failed));
  }

  PetInput _input() {
    String? clean(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    return PetInput(
      name: _name.text.trim(),
      species: _species,
      sex: _sex,
      breed: clean(_breed),
      birthDate: _birthDate,
      birthDateApproximate: _birthDate != null && _birthDateApproximate,
      // A switch can't say "unknown": switched off, a pet whose status was
      // never given stays unknown instead of becoming "not neutered".
      neutered: _neutered
          ? true
          : (widget.pet?.neutered == null ? null : false),
      neuteredOn: _neutered ? _neuteredOn : null,
      color: clean(_color),
      markings: clean(_markings),
      allergies: clean(_allergies),
      notes: clean(_notes),
      identifiers: [for (final draft in _identifiers) draft.toIdentifier()],
    );
  }

  Future<void> _save() async {
    if (_fromCopy) {
      setState(() => _failure = context.l10n.formOpenedOffline);
      return;
    }
    if (_busy) return;
    final l10n = context.l10n;
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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final pets = ref.read(petsRepositoryProvider);
    final files = ref.read(filesRepositoryProvider);
    final input = _input();
    final newPhoto = _newPhoto;
    Pet? saved;
    setState(() => _busy = true);
    try {
      // Upload first: if the photo is refused (too large, wrong type),
      // nothing is saved yet and the user can pick another one.
      var photo = _uploadedPhoto;
      if (newPhoto != null && photo == null) {
        setState(() => _uploadingPhoto = true);
        photo = await files.upload(newPhoto);
        _uploadedPhoto = photo;
        if (mounted) setState(() => _uploadingPhoto = false);
      }

      final pet = widget.pet;
      saved = pet == null
          ? await pets.createPet(input)
          : await pets.updatePet(pet.id, input);
      container.read(appEventsProvider).action(AppAction.petSaved);

      if (photo != null) {
        await pets.setPhoto(saved.id, photo.id);
      } else if (_removePhoto && pet?.photo != null) {
        await pets.removePhoto(saved.id);
      }
      refreshPet(container, saved.id);
      if (mounted) navigator.pop();
    } catch (error) {
      debugPrint('Saving the pet failed: $error');
      if (saved != null) {
        // The pet is saved; only the photo step failed. Leave the form, so
        // saving again doesn't add the pet twice.
        refreshPet(container, saved.id);
        if (mounted) navigator.pop();
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.petPhotoSaveFailed)),
        );
        return;
      }
      if (!mounted) return;
      final fieldErrors = fieldErrorsOf(error);
      final placed =
          fieldErrors.isNotEmpty &&
          fieldErrors.keys.every((key) => _fieldKeys.hasMatch(key));
      setState(() {
        _uploadingPhoto = false;
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
    final identifiersError = _serverError('identifiers');
    const gap = SizedBox(height: CbSpace.s4);
    const sectionGap = SizedBox(height: CbSpace.s8);

    return LeaveGuard(
      busy: _busy,
      changed: () => valuesChanged(_opened, _values()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? l10n.petFormEditTitle : l10n.petFormAddTitle),
        ),
        bottomNavigationBar: CbSaveBar(
          busy: _busy,
          error: _failure,
          busyLabel: _uploadingPhoto ? l10n.petPhotoUploading : null,
          onSave: () => inOpenedHousehold(_save),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          // Not a lazy list: every field is built, so every field is checked.
          // Every field has its own key: rows that come and go (the neutering
          // date) must not hand a field's text or focus to another field.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s4,
              CbSpace.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PhotoSlot(
                  key: const ValueKey('photo'),
                  name: _name.text,
                  savedPhoto: _removePhoto ? null : widget.pet?.photo,
                  newPhoto: _newPhoto,
                  onTap: _busy ? null : _choosePhoto,
                ),
                sectionGap,
                CbTextField(
                  key: const ValueKey('name'),
                  label: l10n.petNameLabel,
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  // The avatar shows the first letter.
                  onChanged: (_) => setState(() {}),
                ),
                gap,
                CbLabeled(
                  key: const ValueKey('species'),
                  label: l10n.petSpeciesLabel,
                  child: SegmentedButton<PetSpecies>(
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    segments: [
                      for (final species in PetSpecies.values)
                        ButtonSegment(
                          value: species,
                          label: Text(petSpeciesShortLabel(l10n, species)),
                        ),
                    ],
                    selected: {_species},
                    onSelectionChanged: (value) =>
                        setState(() => _species = value.single),
                  ),
                ),
                gap,
                CbLabeled(
                  key: const ValueKey('sex'),
                  label: l10n.petSexLabel,
                  child: SegmentedButton<PetSex>(
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    segments: [
                      for (final sex in [
                        PetSex.female,
                        PetSex.male,
                        PetSex.unknown,
                      ])
                        ButtonSegment(
                          value: sex,
                          label: Text(petSexLabel(l10n, sex)),
                        ),
                    ],
                    selected: {_sex},
                    onSelectionChanged: (value) =>
                        setState(() => _sex = value.single),
                  ),
                ),
                gap,
                CbTextField(
                  key: const ValueKey('breed'),
                  label: l10n.petBreedLabel,
                  hintText: l10n.petBreedHint,
                  controller: _breed,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      _maxLength(value, _maxBreed) ?? _serverError('breed'),
                ),
                gap,
                CbDateField(
                  key: const ValueKey('birthDate'),
                  label: l10n.petBirthDateLabel,
                  value: _birthDate,
                  onChanged: (date) => setState(() => _birthDate = date),
                  validator: (_) => _serverError('birthDate'),
                ),
                if (_birthDate != null)
                  _SwitchRow(
                    key: const ValueKey('birthDateApproximate'),
                    label: l10n.petBirthDateApproximate,
                    value: _birthDateApproximate,
                    onChanged: (value) =>
                        setState(() => _birthDateApproximate = value),
                  ),
                gap,
                _SwitchRow(
                  key: const ValueKey('neutered'),
                  label: l10n.petNeuteredLabel,
                  value: _neutered,
                  onChanged: (value) => setState(() {
                    _neutered = value;
                    if (!value) _neuteredOn = null;
                  }),
                ),
                if (_neutered) ...[
                  const SizedBox(height: CbSpace.s2),
                  CbDateField(
                    key: const ValueKey('neuteredOn'),
                    label: l10n.petNeuteredOnLabel,
                    value: _neuteredOn,
                    firstDate: _birthDate,
                    onChanged: (date) => setState(() => _neuteredOn = date),
                    validator: (date) {
                      final born = _birthDate;
                      if (date != null && born != null && date.isBefore(born)) {
                        return l10n.petNeuteredBeforeBirth;
                      }
                      return _serverError('neuteredOn');
                    },
                  ),
                ],
                gap,
                CbTextField(
                  key: const ValueKey('color'),
                  label: l10n.petColorLabel,
                  hintText: l10n.petColorHint,
                  controller: _color,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      _maxLength(value, _maxColor) ?? _serverError('color'),
                ),
                gap,
                CbTextField(
                  key: const ValueKey('markings'),
                  label: l10n.petMarkingsLabel,
                  hintText: l10n.petMarkingsHint,
                  controller: _markings,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  validator: (value) =>
                      _maxLength(value, _maxMarkings) ??
                      _serverError('markings'),
                ),
                sectionGap,
                CbSection(
                  key: const ValueKey('identifiers'),
                  title: l10n.identifiersTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final draft in _identifiers) ...[
                        IdentifierCard(
                          key: draft.key,
                          draft: draft,
                          onChanged: () => setState(() {}),
                          onRemove: () => _removeIdentifier(draft),
                          onScan: _busy ? null : () => _scanChip(draft),
                          codeValidator: (_) => _validateIdentifierCode(draft),
                          fieldError: (field) =>
                              _identifierFieldError(draft, field),
                        ),
                        const SizedBox(height: CbSpace.s3),
                      ],
                      if (_identifiers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: CbSpace.s3),
                          child: Text(
                            l10n.identifiersEmpty,
                            style: context.cbText.body.copyWith(
                              color: context.cb.inkMuted,
                            ),
                          ),
                        ),
                      if (identifiersError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: CbSpace.s3),
                          child: Text(
                            identifiersError,
                            style: context.cbText.caption.copyWith(
                              color: context.cb.danger,
                            ),
                          ),
                        ),
                      if (_identifiers.length < IdentifierRules.maxIdentifiers)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _addIdentifier,
                            icon: const Icon(Symbols.add_rounded),
                            label: Text(l10n.identifiersAdd),
                          ),
                        ),
                    ],
                  ),
                ),
                sectionGap,
                CbTextField(
                  key: const ValueKey('allergies'),
                  label: l10n.petAllergiesLabel,
                  hintText: l10n.petAllergiesHint,
                  controller: _allergies,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  validator: (value) =>
                      _maxLength(value, _maxAllergies) ??
                      _serverError('allergies'),
                ),
                gap,
                CbTextField(
                  key: const ValueKey('notes'),
                  label: l10n.petNotesLabel,
                  controller: _notes,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 6,
                  validator: (value) =>
                      _maxLength(value, _maxNotes) ?? _serverError('notes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The photo at the top of the form, with "Add photo" or "Change photo".
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    super.key,
    required this.name,
    required this.savedPhoto,
    required this.newPhoto,
    required this.onTap,
  });

  final String name;
  final StoredFile? savedPhoto;
  final PickedMedia? newPhoto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final newPhoto = this.newPhoto;
    const size = PetAvatar.photoSize;
    final hasPhoto = newPhoto != null || savedPhoto != null;
    return Column(
      children: [
        Semantics(
          button: true,
          label: hasPhoto ? l10n.petPhotoChange : l10n.petPhotoAdd,
          child: GestureDetector(
            onTap: onTap,
            child: newPhoto != null
                ? ClipOval(
                    child: Image.file(
                      File(newPhoto.path),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          PetAvatar(name: name, size: size),
                    ),
                  )
                : PetAvatar(name: name, photo: savedPhoto, size: size),
          ),
        ),
        const SizedBox(height: CbSpace.s2),
        OutlinedButton.icon(
          style: cbCompactOutlinedButtonStyle,
          onPressed: onTap,
          icon: const Icon(Symbols.photo_camera_rounded),
          label: Text(hasPhoto ? l10n.petPhotoChange : l10n.petPhotoAdd),
        ),
      ],
    );
  }
}

/// A full-width row with a label and a switch.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: context.cbText.body),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Reloads what shows a pet after it was added or changed (here, or in the
/// onboarding): the list, the pet's page and Today (which shows the pet's
/// name and photo), through the container: it works even after the screen
/// is gone.
void refreshPet(ProviderContainer container, String petId) {
  container.invalidate(petsProvider);
  container.invalidate(petProvider(petId));
  container.invalidate(todayProvider);
  // An archived pet eats no more of the food in supplies.
  refreshSupplyEstimates(container);
}
