import 'package:flutter/services.dart';

import '../../data/api/api_exception.dart';
import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import 'household.dart';

// The words for households and roles, the invite code as people type it,
// and what the household endpoints' refusals mean.

/// The name the server gives a person's first household
/// (`CurrentUserAccessor.DefaultHouseholdName`).
const defaultHouseholdName = 'Home';

/// [name] as the app shows it. The server names a person's first household
/// "Home": its owner sees "My home" («Мой дом»), anyone else "Home" («Дом»),
/// in the user's language. [role] is the user's role there, if known.
String householdName(
  AppLocalizations l10n,
  String name, {
  HouseholdRole? role,
}) => name != defaultHouseholdName
    ? name
    : role == HouseholdRole.owner
    ? l10n.householdDefaultName
    : l10n.householdDefaultNameOther;

String householdRoleLabel(AppLocalizations l10n, HouseholdRole role) =>
    switch (role) {
      HouseholdRole.owner => l10n.householdRoleOwner,
      HouseholdRole.member => l10n.householdRoleMember,
      HouseholdRole.helper => l10n.householdRoleHelper,
    };

/// What the role may do, in one line.
String householdRoleHelper(AppLocalizations l10n, HouseholdRole role) =>
    switch (role) {
      HouseholdRole.owner => l10n.householdRoleOwnerHelper,
      HouseholdRole.member => l10n.householdRoleMemberHelper,
      HouseholdRole.helper => l10n.householdRoleHelperHelper,
    };

/// A person as the list shows them: the name, else the e-mail.
String memberName(AppLocalizations l10n, HouseholdMember member) =>
    member.displayName ?? member.email ?? l10n.householdNoName;

/// Days an invite still works, counted up: a new one says 7.
int inviteDaysLeft(HouseholdInvite invite, DateTime now) {
  final left = invite.expiresAt.difference(now);
  final days = (left.inMinutes / Duration.minutesPerDay).ceil();
  return days < 1 ? 1 : days;
}

/// A message for a failed household request: the refusals the server names
/// (the last owner, a code that doesn't work...) in the app's words, else
/// the usual one.
String householdErrorMessage(Object error, AppLocalizations l10n) {
  if (error is ApiException) {
    switch (error.problemType) {
      case ProblemTypes.lastOwner:
        return l10n.householdLastOwner;
      case ProblemTypes.alreadyAMember:
        return l10n.joinAlreadyMember;
      case ProblemTypes.householdLimit:
        return l10n.householdLimit;
      case ProblemTypes.inviteLimit:
        return l10n.householdInviteLimit;
      case ProblemTypes.householdNotEmpty:
        return l10n.householdNotEmpty;
    }
    if (error.statusCode == 429) return l10n.joinTooManyAttempts;
  }
  return errorMessageFor(error, l10n);
}

/// The invite code as it is typed or pasted: letters and digits in upper
/// case, a hyphen after the fourth, at most 8 (`ABCD-2345`). A pasted
/// message ("…code ABCD-2345, valid for 7 days") gives just its code.
class InviteCodeFormatter extends TextInputFormatter {
  static const length = 8;

  static final _inText = RegExp(r'\b([A-Za-z0-9]{4})-?([A-Za-z0-9]{4})\b');
  static final _notCode = RegExp('[^A-Z0-9]');

  /// Codes are made of `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`: no O and 0, no I
  /// and 1, which are easy to mix up (the server's `InviteCodes`).
  static final _neverInCodes = RegExp('[01IO]');

  /// Whether [digits] (from [digitsOf]) has a character codes never have.
  static bool impossible(String digits) => _neverInCodes.hasMatch(digits);

  /// The code in [text] without the hyphen, e.g. `ABCD2345`. In a message,
  /// the last code-like word: the group's name comes before the code.
  static String digitsOf(String text) {
    final found = _inText.allMatches(text).lastOrNull;
    final raw = found != null && text.length > length + 1
        ? '${found.group(1)}${found.group(2)}'
        : text;
    final code = raw.toUpperCase().replaceAll(_notCode, '');
    return code.length > length ? code.substring(0, length) : code;
  }

  /// `ABCD2345` → `ABCD-2345`; shorter codes get the hyphen once there is
  /// something after it, so deleting goes past it.
  static String format(String digits) => digits.length <= 4
      ? digits
      : '${digits.substring(0, 4)}-${digits.substring(4)}';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = format(digitsOf(newValue.text));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
