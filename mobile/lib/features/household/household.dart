import 'package:flutter/foundation.dart';

/// A person's role in a household (spec, "Семья"). The server checks it on
/// every request; the app only hides what the role can't do.
enum HouseholdRole {
  /// Everything, and the people: invites, roles, the group's name.
  owner,

  /// Everything with the pets and their records, but not the people.
  member,

  /// Sees everything; marks feedings, "Done", visits and purchases.
  helper,
}

/// The household a request is about, as `/me` names it, with the user's
/// role there.
@immutable
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.timeZone,
    required this.role,
  });

  final String id;
  final String name;

  /// IANA time zone, e.g. `Europe/Berlin`: feeding times and reminders are
  /// in it.
  final String timeZone;
  final HouseholdRole role;
}

/// One of the households the user is in ("Home", "Office"), for the list
/// to switch between them.
@immutable
class HouseholdSummary {
  const HouseholdSummary({
    required this.id,
    required this.name,
    required this.role,
    required this.timeZone,
    required this.memberCount,
  });

  final String id;
  final String name;
  final HouseholdRole role;
  final String timeZone;
  final int memberCount;
}

/// A person in the household.
@immutable
class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.isMe,
    this.displayName,
    this.email,
  });

  final String userId;
  final String? displayName;

  /// Null when the server doesn't show it: helpers see only names.
  final String? email;
  final HouseholdRole role;
  final DateTime joinedAt;

  /// The signed-in user.
  final bool isMe;
}

/// A one-time code to join the household, valid for 7 days.
@immutable
class HouseholdInvite {
  const HouseholdInvite({
    required this.id,
    required this.code,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;

  /// As people read it out: `ABCD-2345`.
  final String code;

  /// Member or helper; someone becomes an owner once they have joined.
  final HouseholdRole role;
  final DateTime createdAt;
  final DateTime expiresAt;
}

/// The household on screen with its people, for the group screen. Only
/// owners get the open [invites].
@immutable
class HouseholdDetails {
  const HouseholdDetails({
    required this.id,
    required this.name,
    required this.timeZone,
    required this.role,
    required this.members,
    required this.invites,
  });

  final String id;
  final String name;
  final String timeZone;

  /// The user's own role here.
  final HouseholdRole role;
  final List<HouseholdMember> members;
  final List<HouseholdInvite> invites;

  Household get household =>
      Household(id: id, name: name, timeZone: timeZone, role: role);
}

/// What a code invites to, before joining.
@immutable
class InvitePreview {
  const InvitePreview({
    required this.householdName,
    required this.role,
    required this.expiresAt,
    this.invitedBy,
    this.alreadyMember = false,
  });

  final String householdName;

  /// The name of the person who invites, when they gave one.
  final String? invitedBy;
  final HouseholdRole role;
  final DateTime expiresAt;

  /// The user is in that household already.
  final bool alreadyMember;
}
