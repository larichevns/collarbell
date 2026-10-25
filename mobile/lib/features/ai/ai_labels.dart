import '../../data/api/api_exception.dart';
import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../care/care.dart';
import '../care/care_labels.dart';
import 'ai.dart';
import 'scan_review.dart';

// Localized words for the AI connection, the scans and the notes, used by
// the AI screen, the scan screen, the Passport tab and the Health tab.

String aiProviderLabel(AppLocalizations l10n, AiProvider provider) =>
    switch (provider) {
      AiProvider.gemini => l10n.aiProviderGemini,
      AiProvider.openAiCompatible => l10n.aiProviderOpenAiCompatible,
      AiProvider.ollama => l10n.aiProviderOllama,
      AiProvider.other => l10n.aiProviderOther,
    };

/// Why the connection test failed, with what to do.
String aiTestProblemLabel(AppLocalizations l10n, AiTestProblem? problem) =>
    switch (problem) {
      AiTestProblem.notConfigured => l10n.aiTestProblemNotConfigured,
      AiTestProblem.busy => l10n.aiTestProblemBusy,
      AiTestProblem.rejected => l10n.aiTestProblemRejected,
      AiTestProblem.wrongAnswer => l10n.aiTestProblemWrongAnswer,
      AiTestProblem.other || null => l10n.errorUnknown,
    };

/// The title of the scan screen for what is being read.
String scanTitle(AppLocalizations l10n, ScanSource source) => switch (source) {
  ScanSource.passportPages => l10n.scanTitlePassport,
  ScanSource.vetDocument => l10n.scanTitleDocument,
  ScanSource.note => l10n.noteTitle,
};

/// The status of a scan, or [fromNote] of a note ("Reading the note…").
String scanStatusLabel(
  AppLocalizations l10n,
  ScanStatus status, {
  bool fromNote = false,
}) => switch (status) {
  ScanStatus.queued => l10n.scanStatusQueued,
  ScanStatus.processing =>
    fromNote ? l10n.noteStatusProcessing : l10n.scanStatusProcessing,
  ScanStatus.ready => l10n.scanStatusReady,
  ScanStatus.applied => l10n.scanStatusApplied,
  ScanStatus.failed => l10n.scanStatusFailed,
  ScanStatus.discarded => l10n.scanStatusDiscarded,
};

/// Why a scan (or [fromNote], a note) failed, with what to do; a reason
/// this app can't name reads as "something went wrong".
String scanErrorMessage(
  AppLocalizations l10n,
  ScanError? error, {
  bool fromNote = false,
}) => switch (error) {
  ScanError.busy => l10n.scanErrorBusy,
  ScanError.notConfigured =>
    fromNote ? l10n.noteErrorNotConfigured : l10n.scanErrorNotConfigured,
  ScanError.rejected => l10n.scanErrorRejected,
  // A note has no photos to lose.
  ScanError.photosMissing when !fromNote => l10n.scanErrorPhotosMissing,
  ScanError.photosMissing ||
  ScanError.unexpected ||
  null => fromNote ? l10n.noteErrorUnexpected : l10n.scanErrorUnexpected,
};

/// Whether AI refused to read a note because the person had the day's
/// notes read already ([ProblemTypes.textLimit]).
bool isNoteLimit(Object error) =>
    error is ApiException && error.problemType == ProblemTypes.textLimit;

/// A message for a scan or a note that couldn't start: the day's notes used
/// up have words of their own, with the limit the server gives (else
/// [AiScan.notesPerDay]); the rest is said as for any request.
String scanStartErrorMessage(Object error, AppLocalizations l10n) {
  if (error is! ApiException || !isNoteLimit(error)) {
    return errorMessageFor(error, l10n);
  }
  reportShownError(error);
  final limit = error.problem?.extensions['limit'];
  return l10n.noteLimitReached(
    limit is num && limit >= 1 ? limit.toInt() : AiScan.notesPerDay,
  );
}

/// What a doubt about a value means, e.g. "Day and month could be swapped.
/// Check against the paper." [identifier] words "already saved" for a
/// microchip number, [weight] "already saved" and "repeated" for a weight;
/// [fromNote], the doubts are about a note the user wrote, not a paper.
String draftIssueMessage(
  AppLocalizations l10n,
  DraftIssue issue, {
  bool identifier = false,
  bool weight = false,
  bool fromNote = false,
}) => switch (issue) {
  DraftIssue.unreadable =>
    fromNote ? l10n.noteIssueUnreadable : l10n.scanIssueUnreadable,
  DraftIssue.ambiguous =>
    fromNote ? l10n.noteIssueAmbiguous : l10n.scanIssueAmbiguous,
  DraftIssue.inFuture => l10n.scanIssueInFuture,
  DraftIssue.endsBeforeStart => l10n.scanIssueEndsBeforeStart,
  DraftIssue.invalidFormat =>
    fromNote ? l10n.noteIssueInvalidFormat : l10n.scanIssueInvalidFormat,
  DraftIssue.alreadySaved =>
    weight
        ? l10n.scanWeightAlreadySaved
        : identifier
        ? l10n.scanIssueAlreadySavedCode
        : l10n.scanIssueAlreadySaved,
  DraftIssue.repeated =>
    weight
        ? l10n.scanWeightRepeated
        : fromNote
        ? l10n.noteIssueRepeated
        : l10n.scanIssueRepeated,
  DraftIssue.differsFromSaved => l10n.scanBadgeDiffers,
  DraftIssue.other => l10n.scanIssueOther,
};

/// The badge of a doubt about a whole entry, or null for doubts about one
/// value.
String? draftIssueBadge(AppLocalizations l10n, DraftIssue issue) =>
    switch (issue) {
      DraftIssue.alreadySaved => l10n.scanBadgeAlreadySaved,
      DraftIssue.repeated => l10n.scanBadgeRepeated,
      DraftIssue.differsFromSaved => l10n.scanBadgeDiffers,
      _ => null,
    };

/// What saving a scan did, for the snackbar: "Saved 3 records · 1 plan
/// updated · 1 weighing added · photos added to the passport pages".
/// [passportFields] and [identifiersSent] are what the save sent, when
/// known: they say which passport details changed, and that numbers the pet
/// had already were skipped.
String scanResultSummary(
  AppLocalizations l10n,
  ScanResult result,
  ScanSource source, {
  List<PassportField> passportFields = const [],
  int identifiersSent = 0,
}) {
  final skipped = identifiersSent - result.identifiersAdded;
  final parts = [
    if (result.recordIds.isNotEmpty)
      l10n.scanSavedRecords(result.recordIds.length),
    if (result.plansMoved > 0) l10n.scanSavedPlans(result.plansMoved),
    if (result.weightsAdded > 0) l10n.scanSavedWeights(result.weightsAdded),
    if (result.identifiersAdded > 0)
      l10n.scanSavedIdentifiers(result.identifiersAdded),
    if (skipped > 0) l10n.scanSkippedIdentifiers(skipped),
    if (result.passportUpdated)
      passportFields.isEmpty
          ? l10n.scanSavedPassport
          : l10n.scanSavedPassportFields(
              [
                for (final field in passportFields)
                  passportFieldLabel(l10n, field),
              ].join(', '),
            ),
    if (result.documentId != null)
      source == ScanSource.passportPages
          ? l10n.scanSavedPhotosPassport
          : l10n.scanSavedPhotosDocument,
  ];
  if (parts.isEmpty) return l10n.scanSavedNothing;
  // The parts read as one sentence: only its first letter is a capital.
  final text = parts.join(' · ');
  return text[0].toUpperCase() + text.substring(1);
}

/// A passport field in a sentence, in lower case: "number", «номер».
String passportFieldLabel(AppLocalizations l10n, PassportField field) =>
    switch (field) {
      PassportField.number => l10n.scanPassportFieldNumber,
      PassportField.country => l10n.scanPassportFieldCountry,
      PassportField.issuedOn => l10n.scanPassportFieldIssuedOn,
    };

/// The title of a scanned record whose page names none: "Rabies
/// vaccination" for a vaccination against rabies, otherwise the kind's
/// name, in the user's language.
String scanDefaultTitle(
  AppLocalizations l10n,
  CareKind kind,
  List<VaccineTarget> targets,
) => kind == CareKind.vaccination && targets.contains(VaccineTarget.rabies)
    ? l10n.scanTitleRabiesVaccination
    : careKindLabel(l10n, kind);
