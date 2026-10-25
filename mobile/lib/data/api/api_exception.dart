import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// RFC 7807 problem details, as the API returns them with
/// `Content-Type: application/problem+json`.
@immutable
class ProblemDetails {
  const ProblemDetails({
    this.type,
    this.title,
    this.status,
    this.detail,
    this.traceId,
    this.errors = const {},
    this.extensions = const {},
  });

  /// Parses a decoded body (a map, or a JSON string when the server sent a
  /// non-JSON content type). Returns null when the body is not a problem.
  static ProblemDetails? tryParse(Object? body) {
    var data = body;
    if (data is String && data.trimLeft().startsWith('{')) {
      try {
        data = jsonDecode(data);
      } on FormatException {
        return null;
      }
    }
    if (data is! Map) return null;
    final Map<Object?, Object?> map = data;
    String? text(String key) {
      final value = map[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final status = map['status'];
    final problem = ProblemDetails(
      type: text('type'),
      title: text('title'),
      status: status is int ? status : null,
      detail: text('detail'),
      traceId: text('traceId'),
      errors: _validationErrors(map['errors']),
      extensions: {
        for (final MapEntry(:key, :value) in map.entries)
          if (key is String && !_members.contains(key)) key: value,
      },
    );
    final looksLikeProblem =
        problem.title != null ||
        problem.type != null ||
        problem.detail != null ||
        problem.status != null;
    return looksLikeProblem ? problem : null;
  }

  final String? type;
  final String? title;
  final int? status;
  final String? detail;

  /// Server-side trace id; shown to the user so a request can be found in
  /// the logs.
  final String? traceId;

  /// Validation errors by field (ASP.NET Core `ValidationProblemDetails`).
  final Map<String, List<String>> errors;

  /// The problem's other members, e.g. an AI limit's `limit` and `used`
  /// (see [AiLimit]).
  final Map<String, Object?> extensions;

  /// The members every problem may have; the others are [extensions].
  static const _members = {
    'type',
    'title',
    'status',
    'detail',
    'instance',
    'traceId',
    'errors',
  };

  static Map<String, List<String>> _validationErrors(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is List)
          '${entry.key}': [
            for (final message in entry.value as List) '$message',
          ],
    };
  }

  @override
  String toString() =>
      'ProblemDetails(status: $status, title: $title, detail: $detail, '
      'traceId: $traceId)';
}

/// The `type` of the problems that say exactly what was refused, so the app
/// can say it in the user's language (the server's problem URNs).
abstract final class ProblemTypes {
  /// 403: the request named a household the user isn't in any more.
  static const notAHouseholdMember =
      'urn:collarbell:problem:not-a-household-member';

  /// 403: the user's role in the household can't do this.
  static const roleForbidden = 'urn:collarbell:problem:role-forbidden';

  /// 409: joining a household the user is in already.
  static const alreadyAMember = 'urn:collarbell:problem:already-a-member';

  /// 409: a person can be in up to 20 households.
  static const householdLimit = 'urn:collarbell:problem:household-limit';

  /// 409: a household can have up to 20 open invites.
  static const inviteLimit = 'urn:collarbell:problem:invite-limit';

  /// 409: a household always keeps an owner.
  static const lastOwner = 'urn:collarbell:problem:last-owner';

  /// 409: only a household without pets and supplies can be deleted.
  static const householdNotEmpty = 'urn:collarbell:problem:household-not-empty';

  /// 409: the month's AI photos are used up, or fewer are left than the
  /// request has: the group's for its plan, or the person's in all their
  /// Free groups (see [AiLimit]). Other 409s of the AI calls have no type
  /// (AI isn't set up), so this one is told apart by its type.
  static const aiLimit = 'urn:collarbell:problem:ai-limit';

  /// 429: AI has read as many of the person's notes as it does in 24 hours
  /// (notes cost no AI photos, but go through the server's key). Other 429s
  /// of the AI calls have no type: too many requests in a minute.
  static const textLimit = 'urn:collarbell:problem:text-limit';

  /// 401: the account was deleted (on another phone, or a moment ago on
  /// this one), and its sign-in token works for up to an hour after: the
  /// app signs out (`AccountDeletedInterceptor`).
  static const accountDeleted = 'urn:collarbell:problem:account-deleted';

  /// 403: deleting the account needs the password typed in the last 5
  /// minutes; the app asks for it again.
  static const recentSignInRequired =
      'urn:collarbell:problem:recent-sign-in-required';

  /// 409: nothing was deleted, because a household's fate isn't the one the
  /// person was shown any more (someone joined, left or became an owner).
  static const deletionPlanChanged =
      'urn:collarbell:problem:deletion-plan-changed';
}

/// Whose AI photos for the month a [ProblemTypes.aiLimit] is about.
enum AiLimitScope {
  /// The group's, for its plan.
  household,

  /// The person's: on Free, one person may use only so many a month in all
  /// their Free groups together.
  person,
}

/// What the server says with a [ProblemTypes.aiLimit]: the plan, the AI
/// photos it allows a month, how many are used, and when the count starts
/// again.
@immutable
class AiLimit {
  const AiLimit({
    required this.scope,
    required this.plan,
    required this.limit,
    required this.used,
    this.requested,
    required this.resetsAt,
  });

  /// The limit [error] ran into; null when it is no AI limit, or when the
  /// server didn't say all of it.
  static AiLimit? of(Object error) {
    if (error is! ApiException || error.problemType != ProblemTypes.aiLimit) {
      return null;
    }
    final members = error.problem?.extensions ?? const {};
    final plan = members['plan'];
    final limit = members['limit'];
    final used = members['used'];
    final requested = members['requested'];
    final resetsAt = members['resetsAt'];
    final resets = resetsAt is String ? DateTime.tryParse(resetsAt) : null;
    if (plan is! String || limit is! num || used is! num || resets == null) {
      return null;
    }
    return AiLimit(
      // An answer without one is about the group, as before there were two.
      scope: members['scope'] == 'person'
          ? AiLimitScope.person
          : AiLimitScope.household,
      plan: plan,
      limit: limit.toInt(),
      used: used.toInt(),
      requested: requested is num ? requested.toInt() : null,
      resetsAt: resets.toLocal(),
    );
  }

  final AiLimitScope scope;

  /// `Free` or `Premium`, as the server names the plan.
  final String plan;

  /// AI photos allowed a month.
  final int limit;

  /// AI photos used this month, with those of passport scans being read.
  final int used;

  /// The photos the refused request had.
  final int? requested;

  /// When the count starts again, on the phone's clock: its date is shown.
  final DateTime resetsAt;

  /// Photos left this month.
  int get left => used >= limit ? 0 : limit - used;
}

/// What went wrong with an API call, independent of HTTP details.
enum ApiErrorKind {
  /// No connection, DNS failure, TLS failure.
  network,
  timeout,
  cancelled,

  /// 400 and 422.
  validation,

  /// 401: missing or expired credentials.
  unauthorized,

  /// 403.
  forbidden,

  /// 404.
  notFound,

  /// 409.
  conflict,

  /// 413: the uploaded file is too large.
  payloadTooLarge,

  /// 415: the uploaded file is not a supported photo or PDF.
  unsupportedMediaType,

  /// 429: too many requests in a row, e.g. more than 10 AI readings a
  /// minute ([ApiException.retryAfter] says how long to wait).
  tooManyRequests,

  /// 5xx.
  server,

  /// 2xx with a body that does not match the contract.
  invalidResponse,

  /// A change asked while the screens showed offline copies, when the
  /// server turned out to be back: not sent, the screens reloaded.
  refreshed,

  /// The sign-in couldn't be renewed: no internet (Firebase is on it).
  signInRenewal,
  unknown,
}

/// Thrown while a request is prepared, before it is sent, when that needs
/// the network and there is none: the sign-in token has to be renewed while
/// the phone has no internet. The API client reports it as a network error.
class NetworkUnavailable implements Exception {
  const NetworkUnavailable([this.cause]);

  final Object? cause;

  @override
  String toString() => 'NetworkUnavailable($cause)';
}

/// Thrown while a request is prepared when Firebase can't renew the sign-in
/// token because it doesn't know the account any more: it was deleted (on
/// another phone, or here) over an hour ago, when the last token ran out.
/// To the app it is the same as the server's 401 account-deleted.
class SignInAccountGone implements Exception {
  const SignInAccountGone([this.cause]);

  final Object? cause;

  @override
  String toString() => 'SignInAccountGone($cause)';
}

/// A change (anything but a read) asked while the server doesn't answer and
/// the screens may show offline copies. It isn't sent: it could act on an
/// old copy, e.g. mark yesterday's feeding from yesterday's Today.
class ChangeWhileOffline implements Exception {
  const ChangeWhileOffline();

  @override
  String toString() => 'ChangeWhileOffline';
}

/// Like [ChangeWhileOffline], but the server turned out to be back: the
/// screens reload with live data, and the user does it again on them.
class ScreensRefreshed implements Exception {
  const ScreensRefreshed();

  @override
  String toString() => 'ScreensRefreshed';
}

/// The only exception type the API client throws.
class ApiException implements Exception {
  const ApiException(
    this.kind, {
    this.statusCode,
    this.problem,
    this.message,
    this.cause,
    this.retryAfter,
  });

  factory ApiException.fromDioException(DioException error) {
    switch (error.error) {
      case ScreensRefreshed():
        return ApiException(
          ApiErrorKind.refreshed,
          message: error.message,
          cause: error,
        );
      case ChangeWhileOffline():
        return ApiException(
          ApiErrorKind.network,
          message: error.message,
          cause: error,
        );
      case NetworkUnavailable():
        return ApiException(
          ApiErrorKind.signInRenewal,
          message: error.message,
          cause: error,
        );
      case SignInAccountGone():
        return ApiException(
          ApiErrorKind.unauthorized,
          problem: const ProblemDetails(type: ProblemTypes.accountDeleted),
          message: error.message,
          cause: error,
        );
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          ApiErrorKind.timeout,
          message: error.message,
          cause: error,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return ApiException(
          ApiErrorKind.network,
          message: error.message,
          cause: error,
        );
      case DioExceptionType.cancel:
        return ApiException(
          ApiErrorKind.cancelled,
          message: error.message,
          cause: error,
        );
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final problem = ProblemDetails.tryParse(error.response?.data);
        return ApiException(
          status == null ? ApiErrorKind.unknown : kindForStatus(status),
          statusCode: status,
          problem: problem,
          message: problem?.title ?? error.message,
          cause: error,
          retryAfter: _retryAfter(error.response?.headers.value('retry-after')),
        );
      case DioExceptionType.unknown:
        return ApiException(
          error.error is FormatException
              ? ApiErrorKind.invalidResponse
              : ApiErrorKind.unknown,
          message: error.message ?? '${error.error}',
          cause: error,
        );
    }
  }

  static ApiErrorKind kindForStatus(int status) {
    return switch (status) {
      400 || 422 => ApiErrorKind.validation,
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      413 => ApiErrorKind.payloadTooLarge,
      415 => ApiErrorKind.unsupportedMediaType,
      429 => ApiErrorKind.tooManyRequests,
      >= 500 && < 600 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };
  }

  final ApiErrorKind kind;
  final int? statusCode;
  final ProblemDetails? problem;

  /// Developer-facing description; never shown to users as is.
  final String? message;
  final Object? cause;

  /// How long a 429 asks to wait (`Retry-After`, in seconds), if it says.
  final Duration? retryAfter;

  static Duration? _retryAfter(String? value) {
    final seconds = int.tryParse(value?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  String? get traceId => problem?.traceId;

  /// What exactly was refused, when the server says it (see [ProblemTypes]).
  String? get problemType => problem?.type;

  @override
  String toString() =>
      'ApiException(${kind.name}, status: $statusCode, '
      '${problem?.detail ?? problem?.title ?? message ?? 'no details'}'
      '${traceId == null ? '' : ', traceId: $traceId'})';
}
