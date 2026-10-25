import '../../data/api/api_exception.dart';
import '../../data/api/app_events.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../auth/auth_repository.dart';
import '../household/household_labels.dart';
import 'account.dart';
import 'account_deletion.dart';

// The words for what deleting the account does, and what its and the data
// export's refusals mean.

/// What deleting the account does to [household], in a sentence or two.
List<String> householdFateLines(
  AppLocalizations l10n,
  HouseholdOutcome household,
) => switch (household.fate) {
  HouseholdFate.deleted => [
    l10n.deleteAccountFateDeleted(household.pets),
    // The others there are helpers: only members and owners keep a group.
    if (household.others > 0) l10n.deleteAccountFateDeletedHelpers,
  ],
  HouseholdFate.kept => [l10n.deleteAccountFateKept],
  HouseholdFate.handedOver => [
    switch (household.newOwner) {
      final name? => l10n.deleteAccountFateHandedOver(name),
      null => l10n.deleteAccountFateHandedOverUnnamed,
    },
  ],
};

/// The last question before the deletion: the groups that go with the
/// account, by name ("My home" for the server's "Home"), and that it can't
/// be undone.
String deleteAccountConfirmMessage(
  AppLocalizations l10n,
  List<HouseholdOutcome> households,
) {
  final names = [
    for (final household in households)
      if (household.fate == HouseholdFate.deleted)
        l10n.quotedName(
          householdName(l10n, household.name, role: household.role),
        ),
  ];
  final joined = names.length < 2
      ? names.join()
      : l10n.namesAnd(
          names.sublist(0, names.length - 1).join(', '),
          names.last,
        );
  return l10n.deleteAccountConfirmBody(names.length, joined);
}

/// A message for a failed deletion: the password (wrong, or typed too long
/// ago for the server), the groups changed since they were shown, the
/// sign-out after it, else the usual one.
String deleteAccountErrorMessage(Object error, AppLocalizations l10n) {
  if (error is SignOutAfterDeletionFailed) {
    return l10n.deleteAccountSignOutFailed;
  }
  if (error is AuthException) {
    return switch (error.failure) {
      AuthFailure.invalidCredentials => l10n.deleteAccountWrongPassword,
      AuthFailure.tooManyRequests => l10n.authErrorTooManyRequests,
      AuthFailure.network => l10n.authErrorNetwork,
      AuthFailure.userDisabled => l10n.authErrorUserDisabled,
      _ => l10n.deleteAccountPasswordCheckFailed,
    };
  }
  final refusal = switch (error) {
    _ when isRecentSignInRequired(error) => l10n.deleteAccountPasswordAgain,
    _ when isDeletionPlanChanged(error) => l10n.deleteAccountPlanChanged,
    _ => null,
  };
  if (refusal == null) return errorMessageFor(error, l10n);
  reportShownError(error);
  return refusal;
}

/// Whether the server wants the password typed again before it deletes the
/// account.
bool isRecentSignInRequired(Object error) =>
    error is ApiException &&
    error.problemType == ProblemTypes.recentSignInRequired;

/// Whether the server deleted nothing because a group's fate changed since
/// the person was shown it.
bool isDeletionPlanChanged(Object error) =>
    error is ApiException &&
    error.problemType == ProblemTypes.deletionPlanChanged;

/// A file's size as people read it: whole kilobytes under a megabyte
/// ("5 KB", not "0.0 MB"), else megabytes with one decimal ("24.5 MB").
String fileSizeLabel(AppLocalizations l10n, int bytes) => bytes < 1000 * 1000
    ? l10n.fileSizeKb((bytes / 1000).ceil().clamp(1, 999))
    : l10n.fileSizeMb(bytes / (1000 * 1000));

/// A message for a failed data export: too many this hour (and how long to
/// wait), else the usual one.
String dataExportErrorMessage(Object error, AppLocalizations l10n) {
  if (error is! ApiException || error.kind != ApiErrorKind.tooManyRequests) {
    return errorMessageFor(error, l10n);
  }
  reportShownError(error);
  final wait = error.retryAfter;
  if (wait == null || wait <= Duration.zero) return l10n.dataExportTooOften;
  // Whole minutes, rounded up: "in 0 minutes" would be too soon.
  return l10n.dataExportTooOftenIn((wait.inSeconds / 60).ceil());
}
