import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../../l10n/l10n.dart';
import '../../shared/widgets/cb_date_field.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_save_bar.dart';
import '../../shared/widgets/cb_text_field.dart';
import '../../shared/widgets/cb_time_field.dart';
import '../../shared/widgets/form_errors.dart';
import '../../theme/collarbell_theme.dart';
import '../care/care_labels.dart' show formatDecimal, parseDecimal;
import '../care/care_rules.dart';
import '../care/widgets/kind_dropdown.dart';
import '../care/widgets/target_chips.dart';
import '../files/page_viewer_screen.dart';
import '../files/stored_file.dart';
import '../pets/pet.dart';
import '../pets/pet_labels.dart';
import '../weight/weight.dart';
import '../weight/weight_labels.dart';
import 'ai.dart';
import 'ai_labels.dart';
import 'scan_review.dart';
import 'widgets/draft_cards.dart';

// Editors of one entry of a scan, opened from the review. They change a
// copy of the entry and hand it back on "Done"; going back drops the
// changes. Nothing is saved to the server here: the review saves. An entry
// of a note ([fromNote]) shows the note's words it was read from, not a
// page.

/// Opens the editor of [entry]; returns the edited copy, or null when the
/// user goes back.
Future<ReviewRecord?> editScanRecord(
  BuildContext context, {
  required ReviewRecord entry,
  required Pet pet,
  required List<StoredFile> pages,
  bool fromNote = false,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ScanRecordEditor(
      entry: entry.copy(),
      pet: pet,
      pages: pages,
      fromNote: fromNote,
    ),
  ),
);

Future<ReviewIdentifier?> editScanIdentifier(
  BuildContext context, {
  required ReviewIdentifier entry,
  required List<String> otherCodes,
  required List<StoredFile> pages,
  bool fromNote = false,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ScanIdentifierEditor(
      entry: entry.copy(),
      otherCodes: otherCodes,
      pages: pages,
      fromNote: fromNote,
    ),
  ),
);

Future<ReviewPassport?> editScanPassport(
  BuildContext context, {
  required ReviewPassport entry,
  required List<StoredFile> pages,
  bool fromNote = false,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ScanPassportEditor(
      entry: entry.copy(),
      pages: pages,
      fromNote: fromNote,
    ),
  ),
);

Future<ReviewWeight?> editScanWeight(
  BuildContext context, {
  required ReviewWeight entry,
  required Pet pet,
  required List<StoredFile> pages,
  bool fromNote = false,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ScanWeightEditor(
      entry: entry.copy(),
      pet: pet,
      pages: pages,
      fromNote: fromNote,
    ),
  ),
);

/// One record of a scan: the fields of the record form, with where it was
/// read on top and the AI's doubts under its fields.
class ScanRecordEditor extends StatefulWidget {
  const ScanRecordEditor({
    super.key,
    required this.entry,
    required this.pet,
    required this.pages,
    this.fromNote = false,
  });

  /// A copy of the entry: what the editor starts from.
  final ReviewRecord entry;
  final Pet pet;

  /// The scan's photos, to look at the page again.
  final List<StoredFile> pages;

  /// Read from a note, not from photos.
  final bool fromNote;

  @override
  State<ScanRecordEditor> createState() => _ScanRecordEditorState();
}

class _ScanRecordEditorState extends State<ScanRecordEditor> {
  final _formKey = GlobalKey<FormState>();
  late var _kind = widget.entry.kind;

  /// What the title field shows for a record without a title of its own.
  /// Left as it is, the record keeps going under its kind's name, so the
  /// name follows a new kind.
  late final _defaultTitle = scanDefaultTitle(
    context.l10n,
    widget.entry.kind,
    widget.entry.targets,
  );
  late final _title = TextEditingController(
    text: widget.entry.title ?? _defaultTitle,
  );
  late DateTime? _performedOn = widget.entry.performedOn;
  late TimeOfDay? _time = widget.entry.performedTime;
  late var _targets = widget.entry.targets;
  late final _product = TextEditingController(text: widget.entry.product);
  late final _manufacturer = TextEditingController(
    text: widget.entry.manufacturer,
  );
  late final _batch = TextEditingController(text: widget.entry.batchNumber);
  late DateTime? _validFrom = widget.entry.validFrom;
  late DateTime? _validUntil = widget.entry.validUntil;
  late final _clinic = TextEditingController(text: widget.entry.clinic);
  late final _vet = TextEditingController(text: widget.entry.veterinarian);

  // With the user's decimal separator ("4,2" in Russian), as in the record
  // form: the context gives the locale once the field is built.
  late final _weight = TextEditingController(
    text: switch (widget.entry.weightKg) {
      final weight? => formatDecimal(context.l10n, weight),
      null => null,
    },
  );
  var _submitted = false;
  String? _failure;

  ReviewRecord get _entry => widget.entry;

  // A field is shown when it belongs to the kind, and whenever the entry
  // has a value in it, so a value is never dropped unseen (as in the record
  // form).
  bool get _showTime => usesTime(_kind) || _entry.performedTime != null;
  bool get _showProduct =>
      usesProduct(_kind) ||
      _entry.product != null ||
      _entry.manufacturer != null ||
      _entry.batchNumber != null;
  bool get _showValidity =>
      usesTargets(_kind) ||
      _entry.validFrom != null ||
      _entry.validUntil != null;

  /// Unlike the fields above, only while the entry is a check-up: the
  /// server keeps a weight on no other kind, so another kind drops it.
  bool get _showWeight => usesExam(_kind);

  @override
  void dispose() {
    for (final controller in [
      _title,
      _product,
      _manufacturer,
      _batch,
      _clinic,
      _vet,
      _weight,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The entry as the fields are now.
  ReviewRecord _result() {
    String? clean(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    final title = _title.text.trim();
    final result = _entry.copy()
      ..kind = _kind
      ..title = _entry.title == null && title == _defaultTitle ? null : title
      ..performedOn = _performedOn
      ..performedTime = _showTime ? _time : null
      ..targets = _targets
      ..product = _showProduct ? clean(_product) : null
      ..manufacturer = _showProduct ? clean(_manufacturer) : null
      ..batchNumber = _showProduct ? clean(_batch) : null
      ..validFrom = _showValidity ? _validFrom : null
      ..validUntil = _showValidity ? _validUntil : null
      ..clinic = clean(_clinic)
      ..veterinarian = clean(_vet)
      ..weightKg = _showWeight ? parseDecimal(_weight.text) : null;
    _entry.markChanges(result);
    return result;
  }

  String? _problem(String field) => recordProblems(
    _result(),
    context.l10n,
    today: CbDateField.today(),
  )[field];

  /// The AI's doubt about [field], until the user changes it.
  String? _doubt(String field) =>
      _doubtText(context, _result(), field, fromNote: widget.fromNote);

  void _done() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitted = true;
      _failure = null;
    });
    final invalid = invalidFields(_formKey.currentState!);
    if (invalid.isNotEmpty) {
      revealTopmost(invalid);
      setState(() => _failure = context.l10n.formCheckFields);
      return;
    }
    Navigator.of(context).pop(_result());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = CbDateField.today();
    const gap = SizedBox(height: CbSpace.s4);
    return _EditorScaffold(
      title: l10n.scanEditRecordTitle,
      formKey: _formKey,
      submitted: _submitted,
      failure: _failure,
      onDone: _done,
      page: _entry.draft.page,
      evidence: _entry.draft.evidence,
      pages: widget.pages,
      fromNote: widget.fromNote,
      children: [
        CbLabeled(
          key: const ValueKey('kind'),
          label: l10n.careKindLabel,
          child: KindDropdown(
            value: _kind,
            validator: (_) => _problem('kind'),
            onChanged: (kind) => setState(() => _kind = kind),
          ),
        ),
        gap,
        CbTextField(
          key: const ValueKey('title'),
          label: l10n.recordTitleLabel,
          hintText: l10n.recordTitleHint,
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          validator: (_) => _problem('title'),
        ),
        gap,
        CbDateField(
          key: const ValueKey('performedOn'),
          label: l10n.recordPerformedOnLabel,
          value: _performedOn,
          firstDate: earliestCareDate,
          clearable: false,
          helperText: _doubt('performedOn'),
          onChanged: (date) => setState(() => _performedOn = date),
          validator: (_) => _problem('performedOn'),
        ),
        if (_showTime) ...[
          gap,
          CbTimeField(
            key: const ValueKey('time'),
            label: l10n.careTimeLabel,
            helperText: l10n.careTimeHelper,
            value: _time,
            onChanged: (time) => setState(() => _time = time),
            validator: (_) => _problem('performedTime'),
          ),
        ],
        if (usesTargets(_kind)) ...[
          gap,
          TargetsFormField(
            key: const ValueKey('targets'),
            species: widget.pet.species,
            selected: _targets,
            serverError: _problem('targets'),
            onChanged: (targets) => setState(() => _targets = targets),
          ),
        ],
        if (_showProduct) ...[
          gap,
          CbTextField(
            key: const ValueKey('product'),
            label: l10n.careProductLabel,
            controller: _product,
            validator: (_) => _problem('product'),
          ),
          gap,
          CbTextField(
            key: const ValueKey('manufacturer'),
            label: l10n.careManufacturerLabel,
            controller: _manufacturer,
            validator: (_) => _problem('manufacturer'),
          ),
          gap,
          CbTextField(
            key: const ValueKey('batch'),
            label: l10n.careBatchLabel,
            controller: _batch,
            monospace: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            validator: (_) => _problem('batchNumber'),
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
            helperText: _doubt('validFrom'),
            onChanged: (date) => setState(() => _validFrom = date),
            validator: (_) => _problem('validFrom'),
          ),
          gap,
          CbDateField(
            key: const ValueKey('validUntil'),
            label: l10n.careValidUntilLabel,
            value: _validUntil,
            firstDate: earliestCareDate,
            lastDate: latestDueDate(today),
            helperText: _doubt('validUntil'),
            onChanged: (date) => setState(() => _validUntil = date),
            validator: (_) => _problem('validUntil'),
          ),
        ],
        if (_showWeight) ...[
          gap,
          CbTextField(
            key: const ValueKey('weight'),
            label: l10n.recordWeightLabel,
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            helperText: _doubt('weightKg'),
            validator: (value) =>
                // A check-up record keeps its weight to 10 g.
                weightTextProblem(
                  l10n,
                  value ?? '',
                  decimals: WeightRules.recordDecimals,
                ) ??
                _problem('weightKg'),
          ),
        ],
        gap,
        CbTextField(
          key: const ValueKey('vet'),
          label: l10n.careVetLabel,
          controller: _vet,
          textCapitalization: TextCapitalization.words,
          validator: (_) => _problem('veterinarian'),
        ),
        gap,
        CbTextField(
          key: const ValueKey('clinic'),
          label: l10n.careClinicLabel,
          controller: _clinic,
          textCapitalization: TextCapitalization.words,
          validator: (_) => _problem('clinic'),
        ),
      ],
    );
  }
}

/// One microchip or tattoo of a scan.
class ScanIdentifierEditor extends StatefulWidget {
  const ScanIdentifierEditor({
    super.key,
    required this.entry,
    required this.otherCodes,
    required this.pages,
    this.fromNote = false,
  });

  final ReviewIdentifier entry;

  /// The codes of the ticked identifiers before this one, normalised.
  final List<String> otherCodes;
  final List<StoredFile> pages;
  final bool fromNote;

  @override
  State<ScanIdentifierEditor> createState() => _ScanIdentifierEditorState();
}

class _ScanIdentifierEditorState extends State<ScanIdentifierEditor> {
  final _formKey = GlobalKey<FormState>();
  late var _type = widget.entry.type;
  late final _code = TextEditingController(text: widget.entry.code);
  late DateTime? _appliedOn = widget.entry.appliedOn;
  late final _location = TextEditingController(text: widget.entry.location);
  var _submitted = false;
  String? _failure;

  @override
  void dispose() {
    _code.dispose();
    _location.dispose();
    super.dispose();
  }

  ReviewIdentifier _result() {
    final location = _location.text.trim();
    final result = widget.entry.copy()
      ..type = _type
      ..code = _code.text.trim()
      ..appliedOn = _appliedOn
      ..location = location.isEmpty ? null : location;
    widget.entry.markChanges(result);
    return result;
  }

  String? _problem(String field) => identifierProblems(
    _result(),
    context.l10n,
    today: CbDateField.today(),
    otherCodes: widget.otherCodes,
  )[field];

  void _done() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitted = true;
      _failure = null;
    });
    final invalid = invalidFields(_formKey.currentState!);
    if (invalid.isNotEmpty) {
      revealTopmost(invalid);
      setState(() => _failure = context.l10n.formCheckFields);
      return;
    }
    Navigator.of(context).pop(_result());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tattoo = _type == IdentifierType.tattoo;
    const gap = SizedBox(height: CbSpace.s4);
    return _EditorScaffold(
      title: l10n.scanEditIdentifierTitle,
      formKey: _formKey,
      submitted: _submitted,
      failure: _failure,
      onDone: _done,
      page: widget.entry.draft.page,
      evidence: widget.entry.draft.evidence,
      pages: widget.pages,
      fromNote: widget.fromNote,
      children: [
        CbLabeled(
          label: l10n.identifierTypeLabel,
          child: DropdownButtonFormField<IdentifierType>(
            icon: cbDropdownIcon,
            initialValue: _type,
            isExpanded: true,
            // Body text, like the text fields (Material's default is bolder).
            style: context.cbText.body.copyWith(color: context.cb.ink),
            items: [
              for (final type in IdentifierType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(
                    identifierTypeLabel(l10n, type),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            validator: (_) => _problem('type'),
            onChanged: (type) {
              if (type != null) setState(() => _type = type);
            },
          ),
        ),
        gap,
        CbTextField(
          key: const ValueKey('code'),
          label: tattoo ? l10n.identifierTattooLabel : l10n.identifierChipLabel,
          controller: _code,
          monospace: true,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          keyboardType: _type == IdentifierType.isoChip
              ? TextInputType.number
              : TextInputType.text,
          helperText:
              _doubtText(
                context,
                _result(),
                'code',
                fromNote: widget.fromNote,
              ) ??
              switch (_type) {
                IdentifierType.isoChip => l10n.identifierIsoHint,
                IdentifierType.legacyChip => l10n.identifierLegacyHint,
                IdentifierType.tattoo => null,
              },
          validator: (_) => _problem('code'),
        ),
        gap,
        CbDateField(
          key: const ValueKey('appliedOn'),
          label: tattoo
              ? l10n.identifierTattooDateLabel
              : l10n.identifierChipDateLabel,
          value: _appliedOn,
          helperText: _doubtText(
            context,
            _result(),
            'appliedOn',
            fromNote: widget.fromNote,
          ),
          onChanged: (date) => setState(() => _appliedOn = date),
          validator: (_) => _problem('appliedOn'),
        ),
        gap,
        CbTextField(
          key: const ValueKey('location'),
          label: l10n.identifierLocationLabel,
          hintText: l10n.identifierLocationHint,
          controller: _location,
          textCapitalization: TextCapitalization.sentences,
          validator: (_) => _problem('location'),
        ),
      ],
    );
  }
}

/// The passport details of a scan, with what is saved under each field.
/// An empty field keeps what is saved; a value changed here replaces it.
class ScanPassportEditor extends StatefulWidget {
  const ScanPassportEditor({
    super.key,
    required this.entry,
    required this.pages,
    this.fromNote = false,
  });

  final ReviewPassport entry;
  final List<StoredFile> pages;
  final bool fromNote;

  @override
  State<ScanPassportEditor> createState() => _ScanPassportEditorState();
}

class _ScanPassportEditorState extends State<ScanPassportEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _number = TextEditingController(text: widget.entry.number);
  late final _country = TextEditingController(
    text: widget.entry.issuingCountry,
  );
  late DateTime? _issuedOn = widget.entry.issuedOn;
  var _submitted = false;
  String? _failure;

  @override
  void dispose() {
    _number.dispose();
    _country.dispose();
    super.dispose();
  }

  ReviewPassport _result() {
    String? clean(String text) => text.trim().isEmpty ? null : text.trim();
    final result = widget.entry.copy()
      ..number = clean(_number.text)
      ..issuingCountry = clean(_country.text)?.toUpperCase()
      ..issuedOn = _issuedOn;
    widget.entry.markChanges(result);
    return result;
  }

  String? _problem(String field) => passportProblems(
    _result(),
    context.l10n,
    today: CbDateField.today(),
  )[field];

  void _done() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitted = true;
      _failure = null;
    });
    final invalid = invalidFields(_formKey.currentState!);
    if (invalid.isNotEmpty) {
      revealTopmost(invalid);
      setState(() => _failure = context.l10n.formCheckFields);
      return;
    }
    Navigator.of(context).pop(_result());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saved = widget.entry.saved;
    final savedNumber = saved.number;
    final savedCountry = saved.issuingCountry;
    final savedIssuedOn = saved.issuedOn;
    const gap = SizedBox(height: CbSpace.s4);
    return _EditorScaffold(
      title: l10n.scanEditPassportTitle,
      formKey: _formKey,
      submitted: _submitted,
      failure: _failure,
      onDone: _done,
      page: widget.entry.draft.page,
      evidence: widget.entry.draft.evidence,
      pages: widget.pages,
      fromNote: widget.fromNote,
      children: [
        CbNotice(message: l10n.scanPassportKeeps),
        gap,
        CbTextField(
          key: const ValueKey('passportNumber'),
          label: l10n.passportNumberLabel,
          hintText: l10n.passportNumberHint,
          controller: _number,
          monospace: true,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          helperText:
              _doubtText(
                context,
                _result(),
                'passportNumber',
                fromNote: widget.fromNote,
              ) ??
              (savedNumber == null ? null : l10n.scanSavedValue(savedNumber)),
          validator: (_) => _problem('passportNumber'),
        ),
        gap,
        CbTextField(
          key: const ValueKey('issuingCountry'),
          label: l10n.passportCountryLabel,
          hintText: l10n.passportCountryHint,
          controller: _country,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          helperText:
              _doubtText(
                context,
                _result(),
                'issuingCountry',
                fromNote: widget.fromNote,
              ) ??
              (savedCountry == null ? null : l10n.scanSavedValue(savedCountry)),
          validator: (_) => _problem('issuingCountry'),
        ),
        gap,
        CbDateField(
          key: const ValueKey('issuedOn'),
          label: l10n.passportIssuedOnLabel,
          value: _issuedOn,
          helperText:
              _doubtText(
                context,
                _result(),
                'issuedOn',
                fromNote: widget.fromNote,
              ) ??
              (savedIssuedOn == null
                  ? null
                  : l10n.scanSavedValue(l10n.dateMedium(savedIssuedOn))),
          onChanged: (date) => setState(() => _issuedOn = date),
          validator: (_) => _problem('issuedOn'),
        ),
      ],
    );
  }
}

/// One weight of a scan or a note: its day and the weight in kilograms, to
/// the gram, checked like a weighing added on the Weight tab.
class ScanWeightEditor extends StatefulWidget {
  const ScanWeightEditor({
    super.key,
    required this.entry,
    required this.pet,
    required this.pages,
    this.fromNote = false,
  });

  final ReviewWeight entry;

  /// Its exact birth date is the first day a weighing can have.
  final Pet pet;
  final List<StoredFile> pages;
  final bool fromNote;

  @override
  State<ScanWeightEditor> createState() => _ScanWeightEditorState();
}

class _ScanWeightEditorState extends State<ScanWeightEditor> {
  final _formKey = GlobalKey<FormState>();
  late DateTime? _measuredOn = widget.entry.measuredOn;

  // With the user's decimal separator ("4,2" in Russian) and to the gram,
  // as the weighing sheet shows it: the context gives the locale once the
  // field is built.
  late final _weight = TextEditingController(
    text: switch (widget.entry.weightKg) {
      final kg? => weightNumberLabel(context.l10n, kg),
      null => null,
    },
  );
  var _submitted = false;
  String? _failure;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  /// The entry as the fields are now.
  ReviewWeight _result() {
    final result = widget.entry.copy()
      ..measuredOn = _measuredOn
      ..weightKg = parseDecimal(_weight.text);
    widget.entry.markChanges(result);
    return result;
  }

  String? _problem(String field) {
    final today = CbDateField.today();
    return weightProblems(
      _result(),
      context.l10n,
      today: today,
      firstDate: WeightRules.firstDateFor(widget.pet, today),
    )[field];
  }

  String? _doubt(String field) =>
      _doubtText(context, _result(), field, fromNote: widget.fromNote);

  void _done() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitted = true;
      _failure = null;
    });
    final invalid = invalidFields(_formKey.currentState!);
    if (invalid.isNotEmpty) {
      revealTopmost(invalid);
      setState(() => _failure = context.l10n.formCheckFields);
      return;
    }
    Navigator.of(context).pop(_result());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const gap = SizedBox(height: CbSpace.s4);
    return _EditorScaffold(
      title: l10n.weightEditTitle,
      formKey: _formKey,
      submitted: _submitted,
      failure: _failure,
      onDone: _done,
      page: widget.entry.draft.page,
      evidence: widget.entry.draft.evidence,
      pages: widget.pages,
      fromNote: widget.fromNote,
      children: [
        CbDateField(
          key: const ValueKey('measuredOn'),
          label: l10n.weightMeasuredOnLabel,
          value: _measuredOn,
          firstDate: WeightRules.firstDateFor(widget.pet, CbDateField.today()),
          clearable: false,
          helperText: _doubt('measuredOn'),
          onChanged: (date) => setState(() => _measuredOn = date),
          validator: (_) => _problem('measuredOn'),
        ),
        gap,
        CbTextField(
          key: const ValueKey('weight'),
          label: l10n.recordWeightLabel,
          hintText: l10n.weightHint,
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          helperText: _doubt('weightKg'),
          validator: (value) =>
              // A weighing keeps its weight to the gram.
              weightTextProblem(
                l10n,
                value ?? '',
                decimals: WeightRules.weighingDecimals,
                required: true,
              ) ??
              _problem('weightKg'),
        ),
      ],
    );
  }
}

/// The AI's doubts about [field] of [entry] in words, until the user
/// changes the field; null when there are none. [fromNote]: the doubts are
/// about a note the user wrote, not a paper.
String? _doubtText(
  BuildContext context,
  Object entry,
  String field, {
  bool fromNote = false,
}) {
  final warnings = switch (entry) {
    ReviewRecord() => entry.fieldWarnings,
    ReviewIdentifier() => entry.fieldWarnings,
    ReviewPassport() => entry.fieldWarnings,
    ReviewWeight() => entry.fieldWarnings,
    _ => const <DraftWarning>[],
  };
  final texts = [
    for (final warning in warnings)
      if (warning.field == field)
        draftIssueMessage(context.l10n, warning.issue, fromNote: fromNote),
  ];
  return texts.isEmpty ? null : texts.join(' ');
}

/// The frame of an editor: where the entry was read, its fields, and
/// "Done" pinned at the bottom.
class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({
    required this.title,
    required this.formKey,
    required this.submitted,
    required this.failure,
    required this.onDone,
    required this.page,
    required this.evidence,
    required this.pages,
    required this.children,
    this.fromNote = false,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final bool submitted;
  final String? failure;
  final VoidCallback onDone;
  final int page;
  final String? evidence;
  final List<StoredFile> pages;
  final List<Widget> children;

  /// The entry was read from a note: its words, no page to open.
  final bool fromNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final photo = page >= 1 && page <= pages.length;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: CbSaveBar(
        busy: false,
        error: failure,
        label: l10n.scanEditDone,
        onSave: onDone,
      ),
      body: Form(
        key: formKey,
        autovalidateMode: submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        // Not a lazy list: every field is built, so every field is checked.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CbSpace.s4,
            CbSpace.s2,
            CbSpace.s4,
            CbSpace.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DraftEvidence(
                page: page,
                evidence: evidence,
                fromNote: fromNote,
                onOpen: photo
                    ? () => openPageViewer(
                        context,
                        pages: pages,
                        initialIndex: page - 1,
                      )
                    : null,
              ),
              const SizedBox(height: CbSpace.s6),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
