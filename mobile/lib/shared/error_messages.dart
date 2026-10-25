import 'package:flutter/material.dart';

import '../data/api/api_exception.dart';
import '../data/api/app_events.dart';
import '../l10n/l10n.dart';

/// A user-facing message for a failed request. Server texts are not shown:
/// they are English and written for developers. The visor hears of it too:
/// its kind and status, never the words.
String errorMessageFor(Object error, AppLocalizations l10n) {
  reportShownError(error);
  if (error is! ApiException) return l10n.errorUnknown;
  // The month's AI photos: told apart by the type, since the AI calls answer
  // 409 without one when AI isn't set up.
  if (isAiLimit(error)) return aiLimitMessage(error, l10n);
  return switch (error.kind) {
    ApiErrorKind.network || ApiErrorKind.timeout => l10n.errorNetwork,
    ApiErrorKind.refreshed => l10n.errorRefreshed,
    ApiErrorKind.signInRenewal => l10n.errorSignInRenewal,
    // The app signs out of a deleted account (AccountDeletedInterceptor).
    ApiErrorKind.unauthorized
        when error.problemType == ProblemTypes.accountDeleted =>
      l10n.accountDeletedNotice,
    ApiErrorKind.unauthorized => l10n.errorUnauthorized,
    // The app moves to the user's first group and says so (HomeShell).
    ApiErrorKind.forbidden
        when error.problemType == ProblemTypes.notAHouseholdMember =>
      l10n.errorNotInHousehold,
    // Any other 403: the user's role in the group can't do this.
    ApiErrorKind.forbidden => l10n.errorForbidden,
    ApiErrorKind.notFound => l10n.errorNotFound,
    ApiErrorKind.validation => l10n.errorValidation,
    ApiErrorKind.payloadTooLarge => l10n.errorFileTooLarge,
    ApiErrorKind.unsupportedMediaType => l10n.errorFileUnsupported,
    ApiErrorKind.tooManyRequests => switch (error.retryAfter?.inSeconds) {
      final seconds? when seconds > 0 && seconds < 60 =>
        l10n.errorTooManyRequestsIn(seconds),
      _ => l10n.errorTooManyRequests,
    },
    ApiErrorKind.server => l10n.errorServer,
    _ => l10n.errorUnknown,
  };
}

/// Whether the request got no answer at all: no connection, or none in
/// time. Trying the next request right away would only wait as long again.
bool isUnreachable(Object error) =>
    error is ApiException &&
    (error.kind == ApiErrorKind.network ||
        error.kind == ApiErrorKind.timeout ||
        error.kind == ApiErrorKind.refreshed ||
        error.kind == ApiErrorKind.signInRenewal);

/// The server trace id of a failed request, if it sent one.
String? traceIdOf(Object error) => error is ApiException ? error.traceId : null;

/// Field errors of a 400 response (`name`, `identifiers[0].code`...), or
/// an empty map for any other failure. Forms show them on their fields (and
/// the visor hears of the failure, like with [errorMessageFor]).
Map<String, List<String>> fieldErrorsOf(Object error) {
  reportShownError(error);
  if (error is ApiException && error.kind == ApiErrorKind.validation) {
    return error.problem?.errors ?? const {};
  }
  return const {};
}

/// What the month's AI limit means for the person: the photos are used up,
/// and the day they count from zero again; or fewer are left than were sent.
/// The group's for its plan, or the person's in all their Free groups.
/// Without the numbers (an older server), just that it's used up.
String aiLimitMessage(Object error, AppLocalizations l10n) {
  final limit = AiLimit.of(error);
  if (limit == null) return l10n.errorAiLimit;
  final plan = switch (limit.plan) {
    'Premium' => l10n.householdPlanPremium,
    'Free' => l10n.householdPlanFree,
    final other => other,
  };
  final someLeft = limit.left > 0;
  return switch (limit.scope) {
    AiLimitScope.household when someLeft => l10n.errorAiLimitNotEnough(
      limit.left,
      limit.limit,
    ),
    AiLimitScope.household => l10n.errorAiLimitUsedUp(
      limit.used,
      limit.limit,
      plan,
      limit.resetsAt,
    ),
    AiLimitScope.person when someLeft => l10n.errorAiLimitPersonNotEnough(
      limit.left,
      limit.limit,
      plan,
    ),
    AiLimitScope.person => l10n.errorAiLimitPersonUsedUp(
      limit.used,
      limit.limit,
      plan,
      limit.resetsAt,
    ),
  };
}

/// Whether AI refused to read photos for the month's limit (see
/// [ProblemTypes.aiLimit]), whatever the status: the screens that read
/// photos offer the plan.
bool isAiLimit(Object error) =>
    error is ApiException && error.problemType == ProblemTypes.aiLimit;

/// Whether the request failed because the signed-in account is deleted (the
/// server's 401 account-deleted, or Firebase no longer knowing it).
bool isAccountDeleted(Object error) =>
    error is ApiException && error.problemType == ProblemTypes.accountDeleted;

/// Whether the request failed because the thing no longer exists, e.g. a
/// plan deleted on another device.
bool isNotFound(Object error) =>
    error is ApiException && error.kind == ApiErrorKind.notFound;

/// After a pull to refresh that failed while the screen still shows its
/// data: says why in a snackbar, since the screen itself shows no error.
void showRefreshFailed(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(errorMessageFor(error, context.l10n))));
}
