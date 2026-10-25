/// A scan's draft as the user checks it: every entry with the values the
/// user left in it, whether it is ticked, and what still needs a look. The
/// review screen keeps one [ScanReview]; saving turns the ticked entries
/// into a [ScanApplyInput], and the server's field errors are put back on
/// the entries they name.
library;

import 'package:flutter/material.dart' show TimeOfDay;

import '../../l10n/l10n.dart';
import '../care/care.dart';
import '../care/care_rules.dart';
import '../passport/passport.dart';
import '../pets/identifier_rules.dart';
import '../pets/pet.dart';
import '../pets/pet_labels.dart';
import '../weight/weight.dart';
import 'ai.dart';

// The server's limits; checked here so mistakes show before saving.
const _maxTitle = 100;
const _maxProduct = 100;
const _maxManufacturer = 100;
const _maxBatch = 50;
const _maxClinic = 200;
const _maxVet = 100;
const _maxLocation = 60;

/// The title of a record that has none of its own, for its kind and
/// diseases, in the user's language (see `scanDefaultTitle`).
typedef DefaultTitle =
    String Function(CareKind kind, List<VaccineTarget> targets);

/// What the review needs of every entry: the tick, whether it can be
/// ticked, and the AI's doubts.
abstract interface class ReviewEntry {
  bool get selected;
  set selected(bool value);

  /// Whether the entry has what it needs to be saved (a date, a number).
  bool get canSelect;

  bool hasIssue(DraftIssue issue);
}

/// A record of the draft as the user has it now. The editor works on a
/// [copy] and hands it back.
class ReviewRecord implements ReviewEntry {
  ReviewRecord.fromDraft(this.draft, {required Set<String> planIds})
    : kind = draft.kind,
      title = draft.title,
      performedOn = draft.performedOn,
      performedTime = draft.performedTime,
      product = draft.product,
      manufacturer = draft.manufacturer,
      batchNumber = draft.batchNumber,
      validFrom = draft.validFrom,
      validUntil = draft.validUntil,
      targets = draft.targets,
      veterinarian = draft.veterinarian,
      clinic = draft.clinic,
      weightKg = draft.weightKg,
      // A plan deleted since the scan was read can't take a "Done".
      planId = planIds.contains(draft.planId) ? draft.planId : null,
      selected = draft.selected && draft.performedOn != null;

  ReviewRecord._copy(ReviewRecord other)
    : draft = other.draft,
      kind = other.kind,
      title = other.title,
      performedOn = other.performedOn,
      performedTime = other.performedTime,
      product = other.product,
      manufacturer = other.manufacturer,
      batchNumber = other.batchNumber,
      validFrom = other.validFrom,
      validUntil = other.validUntil,
      targets = other.targets,
      veterinarian = other.veterinarian,
      clinic = other.clinic,
      weightKg = other.weightKg,
      planId = other.planId,
      selected = other.selected {
    changed.addAll(other.changed);
    serverErrors.addAll(other.serverErrors);
  }

  /// What the AI read; it never changes.
  final DraftRecord draft;
  CareKind kind;

  /// As read from the page or typed by the user. Null when neither gave
  /// one: the record is then shown and saved under its kind's name in the
  /// user's language ([titleOr]), which follows the kind and the diseases.
  String? title;
  DateTime? performedOn;
  TimeOfDay? performedTime;
  String? product;
  String? manufacturer;
  String? batchNumber;
  DateTime? validFrom;
  DateTime? validUntil;
  List<VaccineTarget> targets;
  String? veterinarian;
  String? clinic;

  /// The pet's weight at a check-up, in kilograms. Saved only while the
  /// record is a check-up (see [ScanReview.sending]): the server keeps a
  /// weight on no other kind.
  double? weightKg;

  /// The plan this record is a "Done" of; null for none.
  String? planId;
  @override
  bool selected;

  /// Fields the user changed (API names): the AI's doubts about them no
  /// longer apply.
  final changed = <String>{};

  /// Fields the server refused at the last save (API names, e.g.
  /// `performedOn`, `planId`; `record` for the entry as a whole).
  final serverErrors = <String>{};

  int get key => draft.key;

  /// Only a record with a date can be saved.
  @override
  bool get canSelect => performedOn != null;

  /// The AI's doubts about values the user hasn't changed.
  List<DraftWarning> get fieldWarnings =>
      _fieldWarnings(draft.warnings, changed);

  @override
  bool hasIssue(DraftIssue issue) =>
      draft.warnings.any((w) => w.issue == issue);

  ReviewRecord copy() => ReviewRecord._copy(this);

  /// The title as shown and saved: its own, or [defaultTitle] for the kind
  /// and diseases as they are now.
  String titleOr(DefaultTitle defaultTitle) =>
      title ?? defaultTitle(kind, targets);

  /// Sets the date [field] (`performedOn`, `validFrom` or `validUntil`) to
  /// what the user chose: the AI's doubt about it and the server's error go.
  void setDate(String field, DateTime date) {
    switch (field) {
      case 'performedOn':
        performedOn = date;
      case 'validFrom':
        validFrom = date;
      case 'validUntil':
        validUntil = date;
      default:
        throw ArgumentError.value(field, 'field', 'not a date of a record');
    }
    changed.add(field);
    serverErrors
      ..remove(field)
      ..remove('record');
  }

  /// Links the record to the plan [id] (null: none).
  void setPlan(String? id) {
    planId = id;
    serverErrors.remove('planId');
  }

  /// Notes which fields [edited] changed against this entry, so their
  /// doubts and server errors go away.
  void markChanges(ReviewRecord edited) {
    final fields = {
      if (edited.kind != kind) 'kind',
      if (edited.title != title) 'title',
      if (edited.performedOn != performedOn) 'performedOn',
      if (edited.performedTime != performedTime) 'performedTime',
      if (edited.product != product) 'product',
      if (edited.manufacturer != manufacturer) 'manufacturer',
      if (edited.batchNumber != batchNumber) 'batchNumber',
      if (edited.validFrom != validFrom) 'validFrom',
      if (edited.validUntil != validUntil) 'validUntil',
      if (!_sameTargets(edited.targets, targets)) 'targets',
      if (edited.veterinarian != veterinarian) 'veterinarian',
      if (edited.clinic != clinic) 'clinic',
      if (edited.weightKg != weightKg) 'weightKg',
    };
    edited.changed.addAll(fields);
    edited.serverErrors.removeAll(fields);
    // Any change answers an error about the entry as a whole.
    if (fields.isNotEmpty) edited.serverErrors.remove('record');
  }

  static bool _sameTargets(List<VaccineTarget> a, List<VaccineTarget> b) =>
      a.length == b.length && a.every(b.contains);
}

/// A microchip or tattoo of the draft as the user has it now.
class ReviewIdentifier implements ReviewEntry {
  ReviewIdentifier.fromDraft(this.draft)
    : type = draft.type,
      code = draft.code ?? '',
      appliedOn = draft.appliedOn,
      location = draft.location,
      selected = draft.selected && (draft.code ?? '').isNotEmpty;

  ReviewIdentifier._copy(ReviewIdentifier other)
    : draft = other.draft,
      type = other.type,
      code = other.code,
      appliedOn = other.appliedOn,
      location = other.location,
      selected = other.selected {
    changed.addAll(other.changed);
    serverErrors.addAll(other.serverErrors);
  }

  final DraftIdentifier draft;
  IdentifierType type;

  /// As the user typed it; empty when it couldn't be read.
  String code;
  DateTime? appliedOn;
  String? location;
  @override
  bool selected;
  final changed = <String>{};
  final serverErrors = <String>{};

  int get key => draft.key;

  /// Only an identifier with a number can be saved.
  @override
  bool get canSelect => code.trim().isNotEmpty;

  List<DraftWarning> get fieldWarnings =>
      _fieldWarnings(draft.warnings, changed);

  @override
  bool hasIssue(DraftIssue issue) =>
      draft.warnings.any((w) => w.issue == issue);

  ReviewIdentifier copy() => ReviewIdentifier._copy(this);

  /// Sets the date it was implanted or applied, as the user chose it.
  void setAppliedOn(DateTime date) {
    appliedOn = date;
    changed.add('appliedOn');
    serverErrors.remove('appliedOn');
  }

  void markChanges(ReviewIdentifier edited) {
    final fields = {
      if (edited.type != type) 'type',
      // The server's code check depends on the type too.
      if (edited.code != code || edited.type != type) 'code',
      if (edited.appliedOn != appliedOn) 'appliedOn',
      if (edited.location != location) 'location',
    };
    edited.changed.addAll(fields);
    edited.serverErrors.removeAll(fields);
  }
}

/// A weight of the draft as the user has it now: saved as a weighing of the
/// pet's log.
class ReviewWeight implements ReviewEntry {
  ReviewWeight.fromDraft(this.draft)
    : measuredOn = draft.measuredOn,
      weightKg = draft.weightKg,
      selected =
          draft.selected && draft.measuredOn != null && draft.weightKg != null;

  ReviewWeight._copy(ReviewWeight other)
    : draft = other.draft,
      measuredOn = other.measuredOn,
      weightKg = other.weightKg,
      selected = other.selected {
    changed.addAll(other.changed);
    serverErrors.addAll(other.serverErrors);
  }

  final DraftWeight draft;

  /// Null when the AI couldn't read it: the weight can't be saved until the
  /// user enters it.
  DateTime? measuredOn;

  /// In kilograms; null when it couldn't be read.
  double? weightKg;
  @override
  bool selected;

  /// Fields the user changed (`measuredOn`, `weightKg`): the AI's doubts
  /// about them no longer apply.
  final changed = <String>{};

  /// Fields the server refused at the last save.
  final serverErrors = <String>{};

  int get key => draft.key;

  /// Only a weight with a date and a number can be saved.
  @override
  bool get canSelect => measuredOn != null && weightKg != null;

  List<DraftWarning> get fieldWarnings =>
      _fieldWarnings(draft.warnings, changed);

  @override
  bool hasIssue(DraftIssue issue) =>
      draft.warnings.any((w) => w.issue == issue);

  ReviewWeight copy() => ReviewWeight._copy(this);

  /// Sets the day it was weighed, as the user chose it.
  void setMeasuredOn(DateTime date) {
    measuredOn = date;
    changed.add('measuredOn');
    serverErrors.remove('measuredOn');
  }

  void markChanges(ReviewWeight edited) {
    final fields = {
      if (edited.measuredOn != measuredOn) 'measuredOn',
      if (edited.weightKg != weightKg) 'weightKg',
    };
    edited.changed.addAll(fields);
    edited.serverErrors.removeAll(fields);
  }
}

/// A field of the passport header that a scan can fill in.
enum PassportField {
  number('passportNumber'),
  country('issuingCountry'),
  issuedOn('issuedOn');

  const PassportField(this.apiName);

  /// The field's name in the API, e.g. in a server error.
  final String apiName;
}

/// The passport details of the draft as the user has them now, against
/// the passport header as saved. A scanned value fills in a field that is
/// empty; it replaces a different saved value only when the user says so
/// ([replace]), or changed that value by hand. An empty field keeps what
/// is saved.
class ReviewPassport implements ReviewEntry {
  ReviewPassport.fromDraft(this.draft, {required this.saved})
    : number = draft.number,
      issuingCountry = draft.issuingCountry,
      issuedOn = draft.issuedOn {
    // The server leaves the card unticked when a value differs from the
    // saved one. Here such a value has its own switch, off until the user
    // turns it on, so the card is ticked when it fills in something the
    // header doesn't have yet and the AI has no other doubts.
    final fillsIn = PassportField.values.any(fills);
    final otherDoubts = draft.warnings.any(
      (w) =>
          w.issue != DraftIssue.ambiguous &&
          w.issue != DraftIssue.differsFromSaved,
    );
    selected = canSelect && (draft.selected || (fillsIn && !otherDoubts));
  }

  ReviewPassport._copy(ReviewPassport other)
    : draft = other.draft,
      saved = other.saved,
      number = other.number,
      issuingCountry = other.issuingCountry,
      issuedOn = other.issuedOn,
      selected = other.selected {
    replace.addAll(other.replace);
    changed.addAll(other.changed);
    serverErrors.addAll(other.serverErrors);
  }

  final DraftPassport draft;

  /// The passport header as saved when the review opened.
  final Passport saved;
  String? number;
  String? issuingCountry;
  DateTime? issuedOn;
  @override
  bool selected = false;

  /// Fields whose different saved value the user agreed to replace.
  final replace = <PassportField>{};
  final changed = <String>{};
  final serverErrors = <String>{};

  /// What [field] would be saved as: the passport number without spaces
  /// and in upper case, the country code in upper case; null when empty.
  Object? valueOf(PassportField field) => switch (field) {
    PassportField.number => _clean(PassportRules.normalizeNumber(number ?? '')),
    PassportField.country => _clean(issuingCountry)?.toUpperCase(),
    PassportField.issuedOn => issuedOn,
  };

  Object? savedValueOf(PassportField field) => switch (field) {
    PassportField.number => saved.number,
    PassportField.country => saved.issuingCountry,
    PassportField.issuedOn => saved.issuedOn,
  };

  /// [field] has a value where the saved header has none.
  bool fills(PassportField field) =>
      valueOf(field) != null && savedValueOf(field) == null;

  /// [field] has a value other than the saved one.
  bool differs(PassportField field) {
    final value = valueOf(field);
    final savedValue = savedValueOf(field);
    return value != null && savedValue != null && value != savedValue;
  }

  /// The fields saving would change: the empty ones filled in, and the
  /// different ones the user agreed to replace.
  List<PassportField> get changes => [
    for (final field in PassportField.values)
      if (fills(field) || (differs(field) && replace.contains(field))) field,
  ];

  /// There is something that could change: a field to fill in or to
  /// replace.
  @override
  bool get canSelect =>
      PassportField.values.any((field) => fills(field) || differs(field));

  List<DraftWarning> get fieldWarnings =>
      _fieldWarnings(draft.warnings, changed);

  @override
  bool hasIssue(DraftIssue issue) =>
      draft.warnings.any((w) => w.issue == issue);

  ReviewPassport copy() => ReviewPassport._copy(this);

  /// Sets the date of issue, as the user chose it: a value set by hand
  /// replaces the saved one.
  void setIssuedOn(DateTime date) {
    issuedOn = date;
    changed.add(PassportField.issuedOn.apiName);
    serverErrors.remove(PassportField.issuedOn.apiName);
    replace.add(PassportField.issuedOn);
  }

  /// Notes which fields [edited] changed against these details: their
  /// doubts and server errors go, and a value typed by hand replaces the
  /// saved one.
  void markChanges(ReviewPassport edited) {
    final fields = {
      if (edited.number != number) PassportField.number,
      if (edited.issuingCountry != issuingCountry) PassportField.country,
      if (edited.issuedOn != issuedOn) PassportField.issuedOn,
    };
    final names = {for (final field in fields) field.apiName};
    edited.changed.addAll(names);
    edited.serverErrors.removeAll(names);
    edited.replace.addAll(fields);
  }
}

/// What a save sends, and which entry each item of it came from: the
/// server names refused values by their position in the request.
class ScanSending {
  const ScanSending({
    required this.input,
    required this.recordKeys,
    required this.identifierKeys,
    this.weightKeys = const [],
    this.passportFields = const [],
  });

  final ScanApplyInput input;

  /// The key of the entry behind `records[i]`.
  final List<int> recordKeys;

  /// The key of the entry behind `identifiers[i]`.
  final List<int> identifierKeys;

  /// The key of the entry behind `weights[i]`.
  final List<int> weightKeys;

  /// The passport fields sent, for the summary of what changed.
  final List<PassportField> passportFields;
}

/// The whole draft as the user checks it.
class ScanReview {
  /// [planIds] are the pet's plans, [savedPassport] its passport header
  /// and [savedCodes] the normalised codes of its microchips and tattoos,
  /// all as the server has them when the review opens.
  ScanReview.fromDraft(
    ScanDraft draft, {
    required Set<String> planIds,
    required Passport savedPassport,
    required this.savedCodes,
  }) : records = [
         for (final record in draft.records)
           ReviewRecord.fromDraft(record, planIds: planIds),
       ],
       identifiers = [
         for (final identifier in draft.identifiers)
           ReviewIdentifier.fromDraft(identifier),
       ],
       passport = draft.passport == null
           ? null
           : ReviewPassport.fromDraft(draft.passport!, saved: savedPassport),
       weights = [
         for (final weight in draft.weights) ReviewWeight.fromDraft(weight),
       ];

  final List<ReviewRecord> records;
  final List<ReviewIdentifier> identifiers;

  /// Replaced by the editor's result.
  ReviewPassport? passport;
  final List<ReviewWeight> weights;

  /// The pet's microchips and tattoos as saved (normalised codes).
  final Set<String> savedCodes;

  bool get isEmpty =>
      records.isEmpty &&
      identifiers.isEmpty &&
      passport == null &&
      weights.isEmpty;

  /// How many entries would be saved; the passport details count when they
  /// change something.
  int get selectedCount =>
      records.where((r) => r.selected).length +
      identifiers.where((i) => i.selected).length +
      (_passportSent ? 1 : 0) +
      weights.where((w) => w.selected).length;

  bool get _passportSent {
    final passport = this.passport;
    return passport != null && passport.selected && passport.changes.isNotEmpty;
  }

  /// Whether the ticked [entry] would pass the pet's limit of microchips
  /// and tattoos. Numbers the pet has already take no place: the server
  /// skips them.
  bool overLimit(ReviewIdentifier entry) {
    if (!entry.selected) return false;
    var free = IdentifierRules.maxIdentifiers - savedCodes.length;
    for (final identifier in identifiers) {
      if (!identifier.selected ||
          savedCodes.contains(IdentifierRules.normalize(identifier.code))) {
        continue;
      }
      free--;
      if (identical(identifier, entry)) return free < 0;
    }
    return false;
  }

  /// Forgets the server's errors of the last save: the next save asks the
  /// server again, as the other forms do.
  void clearServerErrors() {
    for (final record in records) {
      record.serverErrors.clear();
    }
    for (final identifier in identifiers) {
      identifier.serverErrors.clear();
    }
    passport?.serverErrors.clear();
    for (final weight in weights) {
      weight.serverErrors.clear();
    }
  }

  /// Puts the editor's result in the place of the entry it was made from.
  void replaceRecord(ReviewRecord edited) {
    final index = records.indexWhere((r) => r.key == edited.key);
    records[index] = edited;
  }

  void replaceIdentifier(ReviewIdentifier edited) {
    final index = identifiers.indexWhere((i) => i.key == edited.key);
    identifiers[index] = edited;
  }

  void replaceWeight(ReviewWeight edited) {
    final index = weights.indexWhere((w) => w.key == edited.key);
    weights[index] = edited;
  }

  /// The ticked entries as the server takes them; a record without a
  /// title of its own goes under [defaultTitle].
  ScanSending sending({
    required bool keepPhotos,
    required DefaultTitle defaultTitle,
  }) {
    final records = [
      for (final record in this.records)
        if (record.selected) record,
    ];
    final identifiers = [
      for (final identifier in this.identifiers)
        if (identifier.selected) identifier,
    ];
    final weights = [
      for (final weight in this.weights)
        if (weight.selected) weight,
    ];
    final passport = this.passport;
    // Only the fields that change: the others stay as saved (null keeps).
    final fields = _passportSent ? passport!.changes : const <PassportField>[];
    Object? sent(PassportField field) =>
        fields.contains(field) ? passport!.valueOf(field) : null;
    return ScanSending(
      input: ScanApplyInput(
        records: [
          for (final record in records)
            ScanRecordInput(
              record: _recordInput(record, defaultTitle),
              planId: record.planId,
            ),
        ],
        identifiers: [
          for (final identifier in identifiers) _identifier(identifier),
        ],
        passport: fields.isEmpty
            ? null
            : ScanPassportInput(
                number: sent(PassportField.number) as String?,
                issuingCountry: sent(PassportField.country) as String?,
                issuedOn: sent(PassportField.issuedOn) as DateTime?,
              ),
        weights: [
          for (final weight in weights)
            ScanWeightInput(
              measuredOn: weight.measuredOn!,
              weightKg: weight.weightKg!,
            ),
        ],
        keepPhotos: keepPhotos,
      ),
      recordKeys: [for (final record in records) record.key],
      identifierKeys: [for (final identifier in identifiers) identifier.key],
      weightKeys: [for (final weight in weights) weight.key],
      passportFields: fields,
    );
  }

  static final _recordError = RegExp(r'^records\[(\d+)\]\.(record\.)?(.+)$');
  static final _identifierError = RegExp(r'^identifiers\[(\d+)\]\.(.+)$');
  static final _passportError = RegExp(r'^passport\.(.+)$');
  static final _weightError = RegExp(r'^weights\[(\d+)\]\.(.+)$');

  /// Puts the field errors of a refused save ([errors], by API name) on the
  /// entries of [sent] they name. Returns false when some error names no
  /// entry, e.g. "records" (too many at once): the screen then says what
  /// went wrong in general.
  bool placeServerErrors(Map<String, List<String>> errors, ScanSending sent) {
    var placedAll = true;
    for (final key in errors.keys) {
      final record = _recordError.firstMatch(key);
      final identifier = _identifierError.firstMatch(key);
      final passport = _passportError.firstMatch(key);
      final weight = _weightError.firstMatch(key);
      if (weight != null) {
        final index = int.parse(weight.group(1)!);
        final entry = index < sent.weightKeys.length
            ? _weightByKey(sent.weightKeys[index])
            : null;
        if (entry == null) {
          placedAll = false;
        } else {
          entry.serverErrors.add(weight.group(2)!);
        }
      } else if (record != null) {
        final index = int.parse(record.group(1)!);
        final entry = index < sent.recordKeys.length
            ? _recordByKey(sent.recordKeys[index])
            : null;
        if (entry == null) {
          placedAll = false;
        } else {
          entry.serverErrors.add(record.group(3)!);
        }
      } else if (identifier != null) {
        final index = int.parse(identifier.group(1)!);
        final entry = index < sent.identifierKeys.length
            ? _identifierByKey(sent.identifierKeys[index])
            : null;
        if (entry == null) {
          placedAll = false;
        } else {
          entry.serverErrors.add(identifier.group(2)!);
        }
      } else if (passport != null && this.passport != null) {
        this.passport!.serverErrors.add(passport.group(1)!);
      } else {
        placedAll = false;
      }
    }
    return placedAll;
  }

  ReviewRecord? _recordByKey(int key) {
    for (final record in records) {
      if (record.key == key) return record;
    }
    return null;
  }

  ReviewIdentifier? _identifierByKey(int key) {
    for (final identifier in identifiers) {
      if (identifier.key == key) return identifier;
    }
    return null;
  }

  ReviewWeight? _weightByKey(int key) {
    for (final weight in weights) {
      if (weight.key == key) return weight;
    }
    return null;
  }

  /// The normalised codes of the ticked identifiers before [entry], so the
  /// second of two equal codes gets the error.
  List<String> codesBefore(ReviewIdentifier entry) => [
    for (final other in identifiers.takeWhile((i) => i.key != entry.key))
      if (other.selected) IdentifierRules.normalize(other.code),
  ];

  static CareRecordInput _recordInput(
    ReviewRecord record,
    DefaultTitle defaultTitle,
  ) => CareRecordInput(
    kind: record.kind,
    title: record.titleOr(defaultTitle).trim(),
    performedOn: record.performedOn!,
    performedTime: record.performedTime,
    product: _clean(record.product),
    manufacturer: _clean(record.manufacturer),
    batchNumber: _clean(record.batchNumber),
    validFrom: record.validFrom,
    validUntil: record.validUntil,
    // Only vaccinations protect against diseases (the server refuses
    // targets on other kinds).
    targets: usesTargets(record.kind) ? record.targets : const [],
    clinic: _clean(record.clinic),
    veterinarian: _clean(record.veterinarian),
    // A weight is noted at a check-up only.
    weightKg: usesExam(record.kind) ? record.weightKg : null,
  );

  static PetIdentifier _identifier(ReviewIdentifier identifier) =>
      PetIdentifier(
        type: identifier.type,
        code: IdentifierRules.normalize(identifier.code),
        rawCode: identifier.code.trim(),
        appliedOn: identifier.appliedOn,
        location: _clean(identifier.location),
      );
}

/// [date] with day and month swapped, for a date the AI wasn't sure about
/// (03/04/2025: 3 April or 4 March?); null when there is no other reading.
DateTime? swapDayAndMonth(DateTime date) =>
    date.day <= 12 && date.day != date.month
    ? DateTime(date.year, date.day, date.month)
    : null;

// --- Problems ---------------------------------------------------------------
//
// What keeps an entry from being saved, by API field name: the server's
// rules (the same as for a record typed in), and the fields the server
// refused at the last save. The review screen shows them on the entry and
// scrolls to the first entry that has any; the editors show them on their
// fields.

/// The problems of [record] on [today].
Map<String, String> recordProblems(
  ReviewRecord record,
  AppLocalizations l10n, {
  required DateTime today,
}) {
  final problems = <String, String>{};
  // Without a title of its own the record goes under its kind's name,
  // which always fits.
  final title = record.title?.trim();
  if (title != null && title.isEmpty) {
    problems['title'] = l10n.recordTitleRequired;
  } else if (title != null && title.length > _maxTitle) {
    problems['title'] = l10n.formTooLong(_maxTitle);
  }
  final performedOn = record.performedOn;
  if (performedOn == null) {
    problems['performedOn'] = l10n.dateRequired;
  } else if (performedOn.isAfter(today)) {
    problems['performedOn'] = l10n.scanDateInFuture;
  } else if (performedOn.isBefore(earliestCareDate)) {
    problems['performedOn'] = l10n.scanDateTooEarly;
  }
  _maxLength(problems, 'product', record.product, _maxProduct, l10n);
  _maxLength(
    problems,
    'manufacturer',
    record.manufacturer,
    _maxManufacturer,
    l10n,
  );
  _maxLength(problems, 'batchNumber', record.batchNumber, _maxBatch, l10n);
  final validFrom = record.validFrom;
  final validUntil = record.validUntil;
  if (validFrom != null &&
      performedOn != null &&
      validFrom.isBefore(performedOn)) {
    problems['validFrom'] = l10n.recordValidFromInvalid;
  }
  if (validUntil != null &&
      ((performedOn != null && !validUntil.isAfter(performedOn)) ||
          (validFrom != null && validUntil.isBefore(validFrom)))) {
    problems['validUntil'] = l10n.recordValidUntilInvalid;
  }
  _maxLength(problems, 'clinic', record.clinic, _maxClinic, l10n);
  _maxLength(problems, 'veterinarian', record.veterinarian, _maxVet, l10n);
  // Another kind doesn't send its weight, so only a check-up's counts.
  final weight = record.weightKg;
  if (weight != null &&
      usesExam(record.kind) &&
      (weight <= 0 || weight > WeightRules.maxKg)) {
    problems['weightKg'] = l10n.recordWeightInvalid;
  }
  for (final field in record.serverErrors) {
    problems.putIfAbsent(field, () => l10n.formServerFieldError);
  }
  return problems;
}

/// The problems of [identifier]; [otherCodes] are the normalised codes of
/// the ticked identifiers before it, and [overLimit] says the pet would
/// pass its limit of microchips and tattoos with it (`entry`: about the
/// entry as a whole).
Map<String, String> identifierProblems(
  ReviewIdentifier identifier,
  AppLocalizations l10n, {
  required DateTime today,
  Iterable<String> otherCodes = const [],
  bool overLimit = false,
}) {
  final problems = <String, String>{
    if (overLimit)
      'entry': l10n.scanTooManyIdentifiers(IdentifierRules.maxIdentifiers),
  };
  final problem = IdentifierRules.check(
    identifier.type,
    identifier.code,
    otherCodes: otherCodes,
  );
  if (problem != null) problems['code'] = identifierProblemLabel(l10n, problem);
  final appliedOn = identifier.appliedOn;
  if (appliedOn != null && appliedOn.isAfter(today)) {
    problems['appliedOn'] = l10n.scanDateInFuture;
  }
  _maxLength(problems, 'location', identifier.location, _maxLocation, l10n);
  for (final field in identifier.serverErrors) {
    problems.putIfAbsent(field, () => l10n.formServerFieldError);
  }
  return problems;
}

/// The problems of [passport].
Map<String, String> passportProblems(
  ReviewPassport passport,
  AppLocalizations l10n, {
  required DateTime today,
}) {
  final problems = <String, String>{};
  final number = PassportRules.normalizeNumber(passport.number ?? '');
  if (number.isNotEmpty && !PassportRules.number.hasMatch(number)) {
    problems['passportNumber'] = l10n.passportNumberInvalid;
  }
  final country = (passport.issuingCountry ?? '').trim();
  if (country.isNotEmpty && !PassportRules.country.hasMatch(country)) {
    problems['issuingCountry'] = l10n.passportCountryInvalid;
  }
  final issuedOn = passport.issuedOn;
  if (issuedOn != null && issuedOn.isAfter(today)) {
    problems['issuedOn'] = l10n.scanDateInFuture;
  }
  for (final field in passport.serverErrors) {
    problems.putIfAbsent(field, () => l10n.formServerFieldError);
  }
  return problems;
}

/// The problems of [weight] on [today], checked like a weighing added on the
/// Weight tab: [firstDate] is the first day a weighing of the pet can have
/// (its exact birth date, else 1990: [WeightRules.firstDateFor]).
Map<String, String> weightProblems(
  ReviewWeight weight,
  AppLocalizations l10n, {
  required DateTime today,
  required DateTime firstDate,
}) {
  final problems = <String, String>{};
  final measuredOn = weight.measuredOn;
  if (measuredOn == null) {
    problems['measuredOn'] = l10n.dateRequired;
  } else if (measuredOn.isAfter(today)) {
    problems['measuredOn'] = l10n.scanDateInFuture;
  } else if (measuredOn.isBefore(WeightRules.earliestDate)) {
    problems['measuredOn'] = l10n.scanDateTooEarly;
  } else if (measuredOn.isBefore(firstDate)) {
    problems['measuredOn'] = l10n.weightDateBeforeBirth;
  }
  final kg = weight.weightKg;
  // In whole grams, as the server keeps it.
  final grams = kg == null ? null : (kg * 1000).round();
  if (grams == null) {
    problems['weightKg'] = l10n.weightRequired;
  } else if (grams <= 0 || grams > WeightRules.maxKg * 1000) {
    problems['weightKg'] = l10n.recordWeightInvalid;
  }
  for (final field in weight.serverErrors) {
    problems.putIfAbsent(field, () => l10n.formServerFieldError);
  }
  return problems;
}

void _maxLength(
  Map<String, String> problems,
  String field,
  String? value,
  int max,
  AppLocalizations l10n,
) {
  if ((value ?? '').trim().length > max) {
    problems[field] = l10n.formTooLong(max);
  }
}

/// The doubts about values that aren't in [changed]; doubts about the whole
/// entry are badges, not field warnings.
List<DraftWarning> _fieldWarnings(
  List<DraftWarning> warnings,
  Set<String> changed,
) => [
  for (final warning in warnings)
    if (!warning.issue.isAboutEntry && !changed.contains(warning.field))
      warning,
];

String? _clean(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
