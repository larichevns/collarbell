// Invite codes (the phone app's household_labels.dart): eight letters and digits a person reads out and types, with a
// hyphen after the fourth (ABCD-2345), never O, 0, I or 1, which are easy to mix up. A pasted message ("…code
// ABCD-2345, valid for 7 days") gives its code. The web's link to join carries the code after "#": a browser never
// sends that part to a server, so the code stays out of every server's request log (as the API takes it in a body).

export const INVITE_CODE_LENGTH = 8;

const IN_TEXT = /\b([A-Za-z0-9]{4})-?([A-Za-z0-9]{4})\b/g;

/**
 * The code in what was typed or pasted, without the hyphen and in capitals: "abcd-2345" → "ABCD2345". In a message,
 * the last code-like word: the group's name comes before the code.
 */
export function inviteCodeOf(text: string): string {
  const found = [...text.matchAll(IN_TEXT)].at(-1);
  const raw = found && text.length > INVITE_CODE_LENGTH + 1 ? `${found[1]}${found[2]}` : text;
  return raw
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .slice(0, INVITE_CODE_LENGTH);
}

/** "ABCD2345" → "ABCD-2345"; a shorter code gets the hyphen once there is something after it. */
export function formatInviteCode(code: string): string {
  return code.length <= 4 ? code : `${code.slice(0, 4)}-${code.slice(4)}`;
}

/** Whether a code has a character codes never have (O, 0, I, 1): said at once, without spending one of the tries. */
export function impossibleInviteCode(code: string): boolean {
  return /[01IO]/.test(code);
}

/** The days an invite still works, counted up: a new one says 7, its last hours 1. */
export function inviteDaysLeft(expiresAt: string, now = Date.now()): number {
  return Math.max(1, Math.ceil((Date.parse(expiresAt) - now) / 86_400_000));
}

/** The address that opens "Join a group" on the web with the code filled in: `joinPage` is its path (/app/join). */
export function inviteLink(code: string, joinPage: string, origin = window.location.origin): string {
  return `${origin}${joinPage}#${code}`;
}
