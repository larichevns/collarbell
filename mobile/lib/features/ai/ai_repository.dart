import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../care/care.dart';
import '../care/care_repository.dart';
import '../files/files_repository.dart';
import '../me/profile_sync.dart';
import '../passport/passport.dart';
import '../passport/passport_repository.dart';
import '../pets/pet.dart';
import '../pets/pets_repository.dart';
import 'ai.dart';

/// The AI connection and the scans of the household's pets. Every method
/// throws ApiException on failure; a scan or pet of another household is
/// "not found".
abstract interface class AiRepository {
  /// Whether AI is set up on the server, its models and this month's use.
  Future<AiStatus> getStatus();

  /// Asks a model about a small picture: does the connection work?
  Future<AiTestResult> testConnection();

  /// Starts reading uploaded photos ([fileIds], in page order) for the pet,
  /// or a note ([text], for [ScanSource.note]: no photos). The server reads
  /// it in the background: poll [getScan] until the scan isn't reading any
  /// more.
  ///
  /// [requestId] is a new id per scan or note the user starts, the same on
  /// every retry: the server answers a retry after a lost response with the
  /// one it already started. [retryOf] is the failed scan or note this
  /// reads again ("Try again"): the server throws it away, whoever started
  /// it, and a note read again keeps the day it was written, which its
  /// "yesterday" is counted from.
  ///
  /// Throws a conflict (409) when AI isn't set up (with
  /// [ProblemTypes.aiLimit]: the month's AI photos are used up), a
  /// validation error (400) when the photos can't be used (unknown, used
  /// already, not photos) or the note is empty, has no words or is too long
  /// (`text`), "too many requests" (429) after too many AI requests in a
  /// minute (with [ProblemTypes.textLimit]: after the day's notes), and "not
  /// found" when the pet is gone.
  Future<AiScan> startScan(
    String petId, {
    required ScanSource source,
    List<String> fileIds = const [],
    String? text,
    String? retryOf,
    required String requestId,
  });

  Future<AiScan> getScan(String id);

  /// The pet's scans still waiting for the user (being read, ready to
  /// check, or failed), newest first, so one can be picked up again. With
  /// [notes] true only the notes, false only the photo scans: each kind has
  /// its own newest 20, so many of one never hide the other.
  Future<List<AiScan>> getPetScans(String petId, {bool? notes});

  /// Saves what the user checked. Safe to repeat: a scan saved before
  /// answers with the first result and saves nothing twice. Throws a
  /// conflict (409) when the draft isn't ready (still reading, or
  /// discarded), and a validation error (400) whose keys name the entries
  /// of [input] (`records[2].record.performedOn`, `identifiers[0].code`,
  /// `passport.issuedOn`, `weights[0].weightKg`...).
  Future<ScanResult> applyScan(String id, ScanApplyInput input);

  /// Throws the scan away (a note's text goes with it). A scan that is gone
  /// already is no error; one that was saved can't be thrown away (409):
  /// what it saved stays.
  Future<void> discardScan(String id);
}

/// [AiRepository] over the generated API client.
class ApiAiRepository implements AiRepository {
  ApiAiRepository(this._client);

  final ApiClient _client;

  @override
  Future<AiStatus> getStatus() async =>
      aiStatusFromDto(await _client.send((api) => api.ai.getAiStatus()));

  @override
  Future<AiTestResult> testConnection() async {
    final test = await _client.send((api) => api.ai.testAi());
    return AiTestResult(
      ok: test.ok,
      model: test.model,
      latency: Duration(milliseconds: test.latencyMs),
      problem: test.ok
          ? null
          : switch (test.problem) {
              dto.AiTestProblem.notConfigured => AiTestProblem.notConfigured,
              dto.AiTestProblem.busy => AiTestProblem.busy,
              dto.AiTestProblem.rejected => AiTestProblem.rejected,
              dto.AiTestProblem.wrongAnswer => AiTestProblem.wrongAnswer,
              null ||
              dto.AiTestProblem.valueNull ||
              dto.AiTestProblem.$unknown => AiTestProblem.other,
            },
    );
  }

  @override
  Future<AiScan> startScan(
    String petId, {
    required ScanSource source,
    List<String> fileIds = const [],
    String? text,
    String? retryOf,
    required String requestId,
  }) async {
    final request = dto.CreateAiImportRequest(
      petId: petId,
      source: switch (source) {
        ScanSource.passportPages => dto.AiImportSource.passportPages,
        ScanSource.vetDocument => dto.AiImportSource.vetDocument,
        ScanSource.note => dto.AiImportSource.text,
      },
      fileIds: fileIds,
      requestId: requestId,
      text: text,
      retryOf: retryOf,
    );
    return aiScanFromDto(
      await _client.send((api) => api.ai.createAiImport(body: request)),
    );
  }

  @override
  Future<AiScan> getScan(String id) async =>
      aiScanFromDto(await _client.send((api) => api.ai.getAiImport(id: id)));

  @override
  Future<List<AiScan>> getPetScans(String petId, {bool? notes}) async {
    final scans = await _client.send(
      (api) => api.ai.listPetAiImports(petId: petId, notes: notes),
    );
    return [for (final scan in scans) aiScanFromDto(scan)];
  }

  @override
  Future<ScanResult> applyScan(String id, ScanApplyInput input) async {
    final passport = input.passport;
    final request = dto.ApplyImportRequest(
      records: [
        for (final item in input.records)
          dto.ImportedRecordRequest(
            // Applying is idempotent as a whole: no request id per record.
            record: careRecordRequestFromInput(item.record, requestId: null),
            planId: item.planId,
          ),
      ],
      identifiers: [
        for (final identifier in input.identifiers)
          petIdentifierRequestFrom(identifier),
      ],
      passport: passport == null
          ? null
          : dto.ApplyPassportRequest(
              passportNumber: passport.number,
              issuingCountry: passport.issuingCountry,
              issuedOn: passport.issuedOn,
            ),
      keepPhotos: input.keepPhotos,
      weights: [
        for (final weight in input.weights)
          dto.ImportedWeightRequest(
            measuredOn: weight.measuredOn,
            // To the gram, as the log keeps it: a double may carry a tail
            // such as 4.2350000001.
            weightKg: (weight.weightKg * 1000).round() / 1000,
          ),
      ],
    );
    return _resultFromDto(
      await _client.send((api) => api.ai.applyAiImport(id: id, body: request)),
    );
  }

  @override
  Future<void> discardScan(String id) async {
    try {
      await _client.send((api) => api.ai.discardAiImport(id: id));
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.notFound) rethrow;
    }
  }
}

// --- Mapping ----------------------------------------------------------------
//
// Values this app doesn't know yet (from a newer server) never crash it: an
// unknown kind of care is shown as "other" (the user can change it before
// saving), unknown vaccine targets are left out, an unknown issue is shown
// as "check this value", and a microchip or tattoo of an unknown type is left
// out of the draft, because it couldn't be saved as what it is.

AiStatus aiStatusFromDto(dto.AiStatusResponse status) => AiStatus(
  configured: status.configured,
  models: [
    for (final model in status.models)
      AiModel(
        provider: switch (model.provider) {
          dto.AiProvider.gemini => AiProvider.gemini,
          dto.AiProvider.openAiCompatible => AiProvider.openAiCompatible,
          dto.AiProvider.ollama => AiProvider.ollama,
          dto.AiProvider.$unknown => AiProvider.other,
        },
        name: model.model,
        ready: model.ready,
      ),
  ],
  freeTier: status.freeTier,
  thisMonth: AiUsage(
    requests: status.thisMonth.requests,
    inputTokens: status.thisMonth.inputTokens,
    outputTokens: status.thisMonth.outputTokens,
  ),
);

AiScan aiScanFromDto(dto.AiImportResponse scan) {
  final draft = scan.draft;
  final result = scan.result;
  return AiScan(
    id: scan.id,
    petId: scan.petId,
    source: switch (scan.source) {
      dto.AiImportSource.vetDocument => ScanSource.vetDocument,
      dto.AiImportSource.text => ScanSource.note,
      dto.AiImportSource.passportPages ||
      dto.AiImportSource.$unknown => ScanSource.passportPages,
    },
    status: switch (scan.status) {
      dto.AiImportStatus.queued => ScanStatus.queued,
      dto.AiImportStatus.processing => ScanStatus.processing,
      dto.AiImportStatus.ready => ScanStatus.ready,
      dto.AiImportStatus.applied => ScanStatus.applied,
      dto.AiImportStatus.discarded => ScanStatus.discarded,
      // A status this app doesn't know can't be shown or saved.
      dto.AiImportStatus.failed ||
      dto.AiImportStatus.$unknown => ScanStatus.failed,
    },
    pages: [for (final page in scan.pages) storedFileFromDto(page)],
    text: scan.text,
    draft: draft == null ? null : _draftFromDto(draft),
    error: switch (scan.error) {
      dto.AiImportError.notConfigured => ScanError.notConfigured,
      dto.AiImportError.busy => ScanError.busy,
      dto.AiImportError.rejected => ScanError.rejected,
      dto.AiImportError.photosMissing => ScanError.photosMissing,
      dto.AiImportError.unexpected => ScanError.unexpected,
      null || dto.AiImportError.valueNull || dto.AiImportError.$unknown => null,
    },
    model: scan.model,
    createdAt: scan.createdAt,
    completedAt: scan.completedAt,
    appliedAt: scan.appliedAt,
    result: result == null ? null : _resultFromDto(result),
  );
}

ScanDraft _draftFromDto(dto.ImportDraft draft) {
  final passport = draft.passport;
  return ScanDraft(
    records: [
      for (final record in draft.records)
        DraftRecord(
          key: record.key,
          kind: careKindFromDto(record.kind),
          title: record.title,
          performedOn: _calendarDate(record.performedOn),
          performedTime: timeFromDto(record.performedTime),
          product: record.product,
          manufacturer: record.manufacturer,
          batchNumber: record.batchNumber,
          validFrom: _calendarDate(record.validFrom),
          validUntil: _calendarDate(record.validUntil),
          targets: vaccineTargetsFromDto(record.targets),
          veterinarian: record.veterinarian,
          clinic: record.clinic,
          weightKg: record.weightKg,
          evidence: record.evidence,
          page: record.page,
          warnings: _warningsFromDto(record.warnings),
          duplicateOf: record.duplicateOf,
          planId: record.planId,
          selected: record.selected,
        ),
    ],
    identifiers: [
      for (final identifier in draft.identifiers)
        if (_identifierTypeFromDto(identifier.type) case final type?)
          DraftIdentifier(
            key: identifier.key,
            type: type,
            code: identifier.code,
            appliedOn: _calendarDate(identifier.appliedOn),
            location: identifier.location,
            evidence: identifier.evidence,
            page: identifier.page,
            warnings: _warningsFromDto(identifier.warnings),
            selected: identifier.selected,
          ),
    ],
    passport: passport == null
        ? null
        : DraftPassport(
            number: passport.passportNumber,
            issuingCountry: passport.issuingCountry,
            issuedOn: _calendarDate(passport.issuedOn),
            evidence: passport.evidence,
            page: passport.page,
            warnings: _warningsFromDto(passport.warnings),
            selected: passport.selected,
          ),
    weights: [
      for (final weight in draft.weights)
        DraftWeight(
          key: weight.key,
          measuredOn: _calendarDate(weight.measuredOn),
          weightKg: weight.weightKg,
          evidence: weight.evidence,
          page: weight.page,
          warnings: _warningsFromDto(weight.warnings),
          duplicateOf: weight.duplicateOf,
          selected: weight.selected,
        ),
    ],
  );
}

IdentifierType? _identifierTypeFromDto(dto.IdentifierType type) =>
    switch (type) {
      dto.IdentifierType.isoChip => IdentifierType.isoChip,
      dto.IdentifierType.legacyChip => IdentifierType.legacyChip,
      dto.IdentifierType.tattoo => IdentifierType.tattoo,
      dto.IdentifierType.$unknown => null,
    };

List<DraftWarning> _warningsFromDto(List<dto.DraftWarning> warnings) => [
  for (final warning in warnings)
    DraftWarning(warning.field, switch (warning.issue) {
      dto.DraftIssue.unreadable => DraftIssue.unreadable,
      dto.DraftIssue.ambiguous => DraftIssue.ambiguous,
      dto.DraftIssue.inFuture => DraftIssue.inFuture,
      dto.DraftIssue.endsBeforeStart => DraftIssue.endsBeforeStart,
      dto.DraftIssue.invalidFormat => DraftIssue.invalidFormat,
      dto.DraftIssue.alreadySaved => DraftIssue.alreadySaved,
      dto.DraftIssue.repeated => DraftIssue.repeated,
      dto.DraftIssue.differsFromSaved => DraftIssue.differsFromSaved,
      dto.DraftIssue.$unknown => DraftIssue.other,
    }),
];

ScanResult _resultFromDto(dto.ApplyImportResponse result) => ScanResult(
  recordIds: result.recordIds,
  plansMoved: result.plansMoved,
  identifiersAdded: result.identifiersAdded,
  passportUpdated: result.passportUpdated,
  documentId: result.documentId,
  weightsAdded: result.weightsAdded,
);

/// Drops any time part: the draft's dates are calendar dates.
DateTime? _calendarDate(DateTime? date) =>
    date == null ? null : DateTime(date.year, date.month, date.day);

// --- Providers --------------------------------------------------------------

final aiRepositoryProvider = Provider<AiRepository>(
  (ref) => ApiAiRepository(ref.watch(apiClientProvider)),
);

/// Whether the server reads photos with AI, for the scan buttons and the AI
/// screen.
///
/// Kept for the session once loaded, so the buttons don't ask again on every
/// pet page; the AI screen and the Passport tab's pull-to-refresh load it
/// again, and the next account loads its own (it follows the profile sync).
/// A failed load isn't kept: the buttons stay hidden, and the next screen
/// that needs it tries again.
final aiStatusProvider = FutureProvider.autoDispose<AiStatus>((ref) async {
  final repository = ref.watch(aiRepositoryProvider);
  final link = ref.keepAlive();
  try {
    await ref.watch(profileSyncProvider.future);
    return await repository.getStatus();
  } catch (_) {
    link.close();
    rethrow;
  }
});

/// The pet's latest photo scans, newest first, for the "continue" cards on
/// the Passport tab. Notes are listed apart ([petNotesProvider]), so many
/// notes never push a scan out of sight, nor the other way round.
final petScansProvider = FutureProvider.autoDispose
    .family<List<AiScan>, String>((ref, petId) async {
      final repository = ref.watch(aiRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getPetScans(petId, notes: false);
    });

/// The pet's latest notes, newest first, for the cards on the Health tab,
/// where notes are written.
final petNotesProvider = FutureProvider.autoDispose
    .family<List<AiScan>, String>((ref, petId) async {
      final repository = ref.watch(aiRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getPetScans(petId, notes: true);
    });

/// Reloads the pet's scans and notes waiting for the user, e.g. after one
/// started, was saved or was thrown away. Like `refreshCare`, it goes
/// through the [container], so it works after the screen is gone.
void refreshPetImports(ProviderContainer container, String petId) {
  container.invalidate(petScansProvider(petId));
  container.invalidate(petNotesProvider(petId));
}

/// What the review of a scan needs to know about the pet, fetched afresh
/// when the review opens: the pet (its species and microchips), its plans
/// (a plan made on another phone since the Health tab loaded can take a
/// "Done") and its passport header (what the scanned details would
/// change).
typedef ScanReviewData = ({Pet pet, List<CarePlan> plans, Passport passport});

final scanReviewDataProvider = FutureProvider.autoDispose
    .family<ScanReviewData, String>((ref, petId) async {
      final pets = ref.watch(petsRepositoryProvider);
      final care = ref.watch(careRepositoryProvider);
      final passports = ref.watch(passportRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      final [pet, plans, passport] = await Future.wait<Object>([
        pets.getPet(petId),
        care.getPlans(petId),
        passports.getPassport(petId),
      ]);
      return (
        pet: pet as Pet,
        plans: plans as List<CarePlan>,
        passport: passport as Passport,
      );
    });
