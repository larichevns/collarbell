import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../care/care.dart';
import '../files/stored_file.dart';
import '../pets/pet.dart';

// --- The AI connection ------------------------------------------------------

/// Who runs an AI model.
enum AiProvider {
  gemini,

  /// Any service with the OpenAI API, e.g. Groq.
  openAiCompatible,

  /// A model on a local Ollama server.
  ollama,

  /// A provider this app doesn't know yet (from a newer server).
  other,
}

/// One model of the chain that reads photos.
@immutable
class AiModel {
  const AiModel({
    required this.provider,
    required this.name,
    required this.ready,
  });

  final AiProvider provider;

  /// The model's id, e.g. `gemini-3.8-flash`.
  final String name;

  /// Set up on the server (for Gemini: it has a key).
  final bool ready;

  @override
  String toString() => 'AiModel(${provider.name}, $name, ready: $ready)';
}

/// The household's use of AI this calendar month.
@immutable
class AiUsage {
  const AiUsage({
    this.requests = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  /// Calls to a model: a scan that falls back to the next model counts
  /// each try.
  final int requests;
  final int inputTokens;
  final int outputTokens;
}

/// Whether the server reads photos with AI (`GET /ai/status`). It is set up
/// in the server's configuration; without it the app hides the scan
/// buttons, and typing records in always works.
@immutable
class AiStatus {
  const AiStatus({
    required this.configured,
    this.models = const [],
    this.freeTier = false,
    this.thisMonth = const AiUsage(),
  });

  static const notConfigured = AiStatus(configured: false);

  final bool configured;

  /// In the order they are tried: the first that answers reads the photos.
  final List<AiModel> models;

  /// Photos go to Gemini's free tier: Google may use them to improve its
  /// products, and people may read them. Only for one's own documents.
  final bool freeTier;
  final AiUsage thisMonth;
}

/// Why "Test connection" failed.
enum AiTestProblem {
  /// No AI model is set up on the server.
  notConfigured,

  /// Every model is busy or out of free requests right now.
  busy,

  /// The AI provider refused the request, e.g. the key is wrong.
  rejected,

  /// A model answered but didn't see the picture.
  wrongAnswer,

  /// A problem this app doesn't know yet (from a newer server).
  other,
}

/// The answer to "Test connection": a model was asked the colour of a
/// square on a small picture.
@immutable
class AiTestResult {
  const AiTestResult({
    required this.ok,
    required this.latency,
    this.model,
    this.problem,
  });

  /// A model answered and saw the picture.
  final bool ok;

  /// The model that answered.
  final String? model;
  final Duration latency;

  /// Why it failed; null when [ok].
  final AiTestProblem? problem;
}

// --- Scans ----------------------------------------------------------------

/// What AI reads: photos, which it decides where to keep when the scan is
/// saved, or a note.
enum ScanSource {
  /// Pages of the pet passport: kept at the end of its passport pages.
  passportPages,

  /// A vaccination certificate, an invoice or another paper from the vet:
  /// kept as a new document.
  vetDocument,

  /// A note the user typed or dictated about the pet ("yesterday the rabies
  /// shot, Nobivac; weighs 4.2"): no photos, the draft is read from its
  /// [AiScan.text].
  note,
}

enum ScanStatus {
  /// Waiting for the server's AI worker.
  queued,

  /// A model is reading the photos.
  processing,

  /// The draft is ready to check.
  ready,

  /// The user saved (some of) the draft.
  applied,
  failed,

  /// The user threw the draft away.
  discarded;

  /// Still being read: the app asks again every few seconds.
  bool get isReading => this == queued || this == processing;
}

/// Why a scan failed.
enum ScanError {
  /// No AI model is set up on the server.
  notConfigured,

  /// Every model is busy or out of free requests right now.
  busy,

  /// The AI provider refused the request, e.g. the key is wrong.
  rejected,

  /// The photos are gone: the server doesn't keep an unsaved scan's photos
  /// for ever (a failed scan's, up to 30 days).
  photosMissing,
  unexpected,
}

/// Why a value of the draft needs a look before it is saved.
enum DraftIssue {
  /// Couldn't be read; it has to be filled in by hand to save the entry.
  unreadable,

  /// Day and month could be either way round, e.g. 03/04/2025.
  ambiguous,
  inFuture,

  /// "Valid until" isn't after the date it was given.
  endsBeforeStart,

  /// Not a valid microchip number, country code or the like; for a weight,
  /// one saving would refuse (a date before the pet was born, over 200 kg).
  invalidFormat,

  /// The same entry is already saved.
  alreadySaved,

  /// The same entry is on two photos (two shots of one page), or twice in a
  /// note; a weight, also when a check-up of the draft has it.
  repeated,

  /// Differs from the passport details already saved.
  differsFromSaved,

  /// An issue this app doesn't know yet (from a newer server).
  other;

  /// About the whole entry rather than one of its values: shown as a badge,
  /// and it stays when the user edits the entry.
  bool get isAboutEntry =>
      this == alreadySaved || this == repeated || this == differsFromSaved;
}

/// One doubt about a draft value.
@immutable
class DraftWarning {
  const DraftWarning(this.field, this.issue);

  /// The API name of the value, e.g. `performedOn`, `code` or `issuedOn`.
  final String field;
  final DraftIssue issue;

  @override
  bool operator ==(Object other) =>
      other is DraftWarning && other.field == field && other.issue == issue;

  @override
  int get hashCode => Object.hash(field, issue);

  @override
  String toString() => 'DraftWarning($field, ${issue.name})';
}

/// A care record the scan found, e.g. a row of the passport's rabies
/// section. Dates are calendar dates.
@immutable
class DraftRecord {
  const DraftRecord({
    required this.key,
    required this.kind,
    this.title,
    this.performedOn,
    this.performedTime,
    this.product,
    this.manufacturer,
    this.batchNumber,
    this.validFrom,
    this.validUntil,
    this.targets = const [],
    this.veterinarian,
    this.clinic,
    this.weightKg,
    this.evidence,
    this.page = 1,
    this.warnings = const [],
    this.duplicateOf,
    this.planId,
    this.selected = true,
  });

  /// Tells the entries of a draft apart.
  final int key;
  final CareKind kind;

  /// As written on the page; null when the page names none (the review
  /// then shows the kind's name in the user's language).
  final String? title;

  /// Null when the date couldn't be read: the entry can't be saved until
  /// the user enters it.
  final DateTime? performedOn;
  final TimeOfDay? performedTime;
  final String? product;
  final String? manufacturer;
  final String? batchNumber;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final List<VaccineTarget> targets;
  final String? veterinarian;
  final String? clinic;

  /// The pet's weight noted at a check-up, in kilograms to 10 g; only a
  /// check-up entry has one.
  final double? weightKg;

  /// The text as it is on the page, so the user can compare.
  final String? evidence;

  /// The photo it was read from, counted from 1.
  final int page;
  final List<DraftWarning> warnings;

  /// The saved record it repeats, if any.
  final String? duplicateOf;

  /// The pet's plan this entry is a "Done" of, as the server suggests.
  final String? planId;

  /// Whether "save this" starts ticked.
  final bool selected;

  @override
  String toString() => 'DraftRecord($key, $title, $performedOn)';
}

/// A microchip or tattoo the scan found.
@immutable
class DraftIdentifier {
  const DraftIdentifier({
    required this.key,
    required this.type,
    this.code,
    this.appliedOn,
    this.location,
    this.evidence,
    this.page = 1,
    this.warnings = const [],
    this.selected = true,
  });

  final int key;
  final IdentifierType type;

  /// Normalised; null when it couldn't be read.
  final String? code;
  final DateTime? appliedOn;
  final String? location;
  final String? evidence;
  final int page;
  final List<DraftWarning> warnings;
  final bool selected;

  @override
  String toString() => 'DraftIdentifier($key, ${type.name}, $code)';
}

/// The passport details the scan found. Saving them fills in the passport
/// header; a field left empty keeps what is saved.
@immutable
class DraftPassport {
  const DraftPassport({
    this.number,
    this.issuingCountry,
    this.issuedOn,
    this.evidence,
    this.page = 1,
    this.warnings = const [],
    this.selected = true,
  });

  final String? number;
  final String? issuingCountry;
  final DateTime? issuedOn;
  final String? evidence;
  final int page;
  final List<DraftWarning> warnings;
  final bool selected;
}

/// A weight the scan or the note gave without an examination ("weighs
/// 4.2"): saving makes it a weighing of the pet's weight log. A weight a vet
/// noted at a check-up comes with the check-up's record instead.
@immutable
class DraftWeight {
  const DraftWeight({
    required this.key,
    this.measuredOn,
    this.weightKg,
    this.evidence,
    this.page = 1,
    this.warnings = const [],
    this.duplicateOf,
    this.selected = true,
  });

  final int key;

  /// A calendar date; null when it couldn't be read.
  final DateTime? measuredOn;

  /// In kilograms, to the gram; null when it couldn't be read.
  final double? weightKg;
  final String? evidence;
  final int page;
  final List<DraftWarning> warnings;

  /// The weight of the log it repeats (a weighing or a vet's), if any.
  final String? duplicateOf;
  final bool selected;

  @override
  String toString() => 'DraftWeight($key, $weightKg kg, $measuredOn)';
}

/// What a scan proposes. Nothing is saved until the user checks it and
/// saves (spec 5.5: AI never writes data itself).
@immutable
class ScanDraft {
  const ScanDraft({
    this.records = const [],
    this.identifiers = const [],
    this.passport,
    this.weights = const [],
  });

  static const empty = ScanDraft();

  final List<DraftRecord> records;
  final List<DraftIdentifier> identifiers;
  final DraftPassport? passport;
  final List<DraftWeight> weights;

  bool get isEmpty =>
      records.isEmpty &&
      identifiers.isEmpty &&
      passport == null &&
      weights.isEmpty;
}

/// What saving a scan did.
@immutable
class ScanResult {
  const ScanResult({
    this.recordIds = const [],
    this.plansMoved = 0,
    this.identifiersAdded = 0,
    this.passportUpdated = false,
    this.documentId,
    this.weightsAdded = 0,
  });

  final List<String> recordIds;

  /// Plans that moved on: a record saved with a plan counts as its "Done".
  final int plansMoved;
  final int identifiersAdded;
  final bool passportUpdated;

  /// The document that keeps the photos, if they were kept.
  final String? documentId;

  /// Weighings added to the pet's weight log.
  final int weightsAdded;
}

/// One scan: the photos the user took (or the note they wrote), the draft
/// the AI made of them, and what was saved.
@immutable
class AiScan {
  const AiScan({
    required this.id,
    required this.petId,
    required this.source,
    required this.status,
    required this.createdAt,
    this.pages = const [],
    this.text,
    this.draft,
    this.error,
    this.model,
    this.completedAt,
    this.appliedAt,
    this.result,
  });

  /// At most this many photos per scan (the server's limit).
  static const maxPages = 10;

  /// At most this many characters in a note, counted after trimming (the
  /// server's limit: a note is a few sentences).
  static const maxNoteLength = 1000;

  /// How many notes one person may have AI read in 24 hours, when the
  /// server's refusal doesn't say (its setting `Ai:TextEntriesPerDay`, 30
  /// by default; the refusal's `limit` says it).
  static const notesPerDay = 30;

  final String id;
  final String petId;
  final ScanSource source;
  final ScanStatus status;

  /// The photos, in page order. A photo that is gone is left out. A note
  /// has none.
  final List<StoredFile> pages;

  /// The note of a [ScanSource.note]; null for photos, and for a note
  /// thrown away.
  final String? text;

  /// Set once [status] is ready.
  final ScanDraft? draft;

  /// Why it failed; null for a failure this app can't name.
  final ScanError? error;

  /// The model that read the photos.
  final String? model;

  /// Moments, not calendar dates.
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? appliedAt;

  /// What saving did, once applied.
  final ScanResult? result;

  bool get isNote => source == ScanSource.note;

  /// A failed scan can be read again, as a new scan of the same photos,
  /// while its photos are there; a failed note, as a new note of the same
  /// text.
  bool get canReadAgain {
    if (status != ScanStatus.failed) return false;
    if (isNote) return (text ?? '').trim().isNotEmpty;
    return pages.isNotEmpty && error != ScanError.photosMissing;
  }

  @override
  String toString() => 'AiScan($id, ${status.name})';
}

/// Whether a note has something to read: a letter or a digit, as the
/// server checks it (.NET's `char.IsLetterOrDigit` on each UTF-16 unit, so
/// letters and decimal digits of the Basic Multilingual Plane).
/// Punctuation, emoji and invisible characters alone are no note.
bool noteHasWords(String text) => _wordCharacter.hasMatch(
  // The server looks at one UTF-16 unit at a time: a character outside the
  // Basic Multilingual Plane (a surrogate pair) is no letter there either.
  String.fromCharCodes(
    text.codeUnits.where((unit) => unit < 0xD800 || unit > 0xDFFF),
  ),
);

final _wordCharacter = RegExp(r'[\p{L}\p{Nd}]', unicode: true);

/// What saving a scan sends (`POST /ai-imports/{id}/apply`): the entries
/// the user ticked, as the user left them.
@immutable
class ScanApplyInput {
  const ScanApplyInput({
    this.records = const [],
    this.identifiers = const [],
    this.passport,
    this.weights = const [],
    this.keepPhotos = true,
  });

  final List<ScanRecordInput> records;
  final List<PetIdentifier> identifiers;
  final ScanPassportInput? passport;
  final List<ScanWeightInput> weights;

  /// Keeps the photos: passport pages at the end of the pet's passport
  /// pages, a vet document as a new document. A note has none to keep.
  final bool keepPhotos;
}

/// One record to save. With [planId] it counts as a "Done" of that plan.
@immutable
class ScanRecordInput {
  const ScanRecordInput({required this.record, this.planId});

  final CareRecordInput record;
  final String? planId;
}

/// Passport header fields to fill in; null fields keep what is saved.
@immutable
class ScanPassportInput {
  const ScanPassportInput({this.number, this.issuingCountry, this.issuedOn});

  final String? number;
  final String? issuingCountry;
  final DateTime? issuedOn;
}

/// A weight to save as a weighing of the pet's log, checked like one added
/// on the Weight tab.
@immutable
class ScanWeightInput {
  const ScanWeightInput({required this.measuredOn, required this.weightKg});

  /// A calendar date.
  final DateTime measuredOn;

  /// In kilograms, to the gram.
  final double weightKg;
}
