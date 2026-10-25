// A failed call in the person's words, the phone app's (mobile/lib/shared/error_messages.dart). The server's own
// texts are not shown: they are English and written for developers.
import type { Messages } from '../i18n/en';
import { ApiError, ProblemTypes } from './client';

export function errorMessage(t: Messages, error: unknown): string {
  if (!(error instanceof ApiError)) return t.errorUnknown;
  const { status, type } = error;
  if (status === 0) return t.errorNetwork;
  if (status === 401) return type === ProblemTypes.accountDeleted ? t.accountDeletedNotice : t.errorUnauthorized;
  if (status === 403) return type === ProblemTypes.notAHouseholdMember ? t.errorNotInHousehold : t.errorForbidden;
  if (status === 404) return t.errorNotFound;
  if (status === 400 || status === 422) return t.errorValidation;
  if (status === 413) return t.errorFileTooLarge;
  if (status === 415) return t.errorFileUnsupported;
  if (status === 429) return t.errorTooManyRequests;
  if (status >= 500) return t.errorServer;
  return t.errorUnknown;
}

/** The thing is gone: deleted on another device, or never in this household. */
export function isNotFound(error: unknown): boolean {
  return error instanceof ApiError && error.status === 404;
}

/** A 400's failed checks by field; empty for any other failure. */
export function fieldErrorsOf(error: unknown): Record<string, string[]> {
  return error instanceof ApiError && (error.status === 400 || error.status === 422) ? error.fields : {};
}

/** A refusal of the household endpoints in words: the last owner, a code that doesn't work… else the usual one. */
export function householdErrorMessage(t: Messages, error: unknown): string {
  if (error instanceof ApiError) {
    switch (error.type) {
      case ProblemTypes.lastOwner:
        return t.householdLastOwner;
      case ProblemTypes.alreadyAMember:
        return t.joinAlreadyMember;
      case ProblemTypes.householdLimit:
        return t.householdLimit;
      case ProblemTypes.inviteLimit:
        return t.householdInviteLimit;
      case ProblemTypes.householdNotEmpty:
        return t.householdNotEmpty;
    }
    // Codes are looked up a few times in ten minutes per person, against guessing.
    if (error.status === 429) return t.joinTooManyAttempts;
  }
  return errorMessage(t, error);
}

/** "Download my data" refused: a few downloads an hour, and how many minutes to wait when the server said. */
export function exportErrorMessage(t: Messages, error: unknown): string {
  if (!(error instanceof ApiError) || error.status !== 429) return errorMessage(t, error);
  const wait = error.retryAfter;
  // Whole minutes, rounded up: "in 0 minutes" would be too soon.
  return wait && wait > 0 ? t.dataExportTooOftenIn(Math.ceil(wait / 60)) : t.dataExportTooOften;
}
