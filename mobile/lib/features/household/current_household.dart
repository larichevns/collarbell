import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/preferences.dart';
import '../../data/api/household_header.dart';
import '../auth/auth_providers.dart';
import 'household.dart';

/// The household the app shows, and what it knows of it: the name and the
/// user's role there. Every request names it (`X-Household`).
@immutable
class CurrentHousehold {
  const CurrentHousehold({required this.id, this.name, this.role});

  factory CurrentHousehold.of(Household household) => CurrentHousehold(
    id: household.id,
    name: household.name,
    role: household.role,
  );

  factory CurrentHousehold.ofSummary(HouseholdSummary household) =>
      CurrentHousehold(
        id: household.id,
        name: household.name,
        role: household.role,
      );

  final String id;

  /// Null until the server has named it, e.g. after a tapped push of
  /// another household.
  final String? name;
  final HouseholdRole? role;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'role': role?.name};

  static CurrentHousehold? fromJson(String? json) {
    if (json == null) return null;
    try {
      final map = jsonDecode(json);
      if (map is! Map || map['id'] is! String) return null;
      final name = map['name'];
      return CurrentHousehold(
        id: map['id'] as String,
        name: name is String ? name : null,
        role: HouseholdRole.values.asNameMap()[map['role']],
      );
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CurrentHousehold &&
      other.id == id &&
      other.name == name &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, name, role);
}

/// The household on screen for the signed-in user; null until the app
/// knows one (the server then answers for the user's first household).
/// Saved on the phone per account, so the app starts in the same household
/// with the role already known, also without a connection.
///
/// Another household here reloads every screen: the profile sync watches it
/// (`profileSyncProvider`), and every data provider waits for the sync.
final currentHouseholdProvider =
    NotifierProvider<CurrentHouseholdNotifier, CurrentHousehold?>(
      CurrentHouseholdNotifier.new,
    );

class CurrentHouseholdNotifier extends Notifier<CurrentHousehold?> {
  /// Where the household of the account [uid] is saved.
  static String keyFor(String uid) => 'household.$uid';

  String? _uid;

  @override
  CurrentHousehold? build() {
    final uid = _uid = ref.watch(authUserProvider.select((user) => user?.uid));
    if (uid == null) return null;
    final preferences = ref.read(sharedPreferencesProvider);
    return CurrentHousehold.fromJson(preferences.getString(keyFor(uid)));
  }

  /// The user picked [household], joined it, or opened a push of it: the
  /// app shows it from now on.
  void switchTo(CurrentHousehold household) => _save(household);

  /// What `/me` answered about the household the app [asked] for (by id;
  /// null: none named): its name and the user's role there, which an owner
  /// may have changed, or which household the server chose. `/me` answers
  /// for the user's first household when the one asked for isn't theirs any
  /// more: the app moves there and says so.
  void remember(Household answer, {required String? asked}) {
    final current = state;
    // Another household was picked meanwhile: the answer is out of date.
    if (current?.id != asked) return;
    if (current != null && current.id != answer.id) _left(current);
    _save(CurrentHousehold.of(answer));
  }

  /// Another answer about the household on screen (the group screen's): its
  /// name and the user's role there. Only `/me` moves the app.
  void refresh(Household answer) {
    if (state?.id == answer.id) _save(CurrentHousehold.of(answer));
  }

  /// The server refused a request for [householdId]: the user isn't in it
  /// any more. The app goes back to the server's choice, their first
  /// household, and says why.
  void lost(String householdId) {
    final current = state;
    if (current == null || current.id != householdId) return;
    _left(current);
    _save(null);
  }

  /// After the user left or deleted [householdId]: when it is the one on
  /// screen, the server's first household from now on. (The app may have
  /// moved on meanwhile, e.g. to a push of another household.)
  void forget(String householdId) {
    if (state?.id == householdId) _save(null);
  }

  void _left(CurrentHousehold household) => ref
      .read(householdNoticeProvider.notifier)
      .report(HouseholdLeft(household.id, household.name, household.role));

  void _save(CurrentHousehold? household) {
    final uid = _uid;
    if (uid == null) return;
    final preferences = ref.read(sharedPreferencesProvider);
    unawaited(
      household == null
          ? preferences.remove(keyFor(uid))
          : preferences.setString(keyFor(uid), jsonEncode(household.toJson())),
    );
    state = household;
  }
}

/// Something the app shell says about a move to another household. A new
/// object every time, so the same household twice is two messages.
sealed class HouseholdNotice {}

/// The app had to leave a household: the user isn't in it any more.
class HouseholdLeft extends HouseholdNotice {
  HouseholdLeft(this.id, this.name, this.role);

  final String id;

  /// Null when the app never learned them.
  final String? name;
  final HouseholdRole? role;
}

/// A tapped push opened another household.
class HouseholdOpened extends HouseholdNotice {
  HouseholdOpened(this.name, this.role);

  /// Null when the app doesn't know them yet.
  final String? name;
  final HouseholdRole? role;
}

/// The last move the app shell has to tell about (`HomeShell`).
final householdNoticeProvider =
    NotifierProvider<HouseholdNoticeNotifier, HouseholdNotice?>(
      HouseholdNoticeNotifier.new,
    );

class HouseholdNoticeNotifier extends Notifier<HouseholdNotice?> {
  @override
  HouseholdNotice? build() => null;

  void report(HouseholdNotice notice) => state = notice;
}

/// Asks `/me` again for the user's role in the household on screen: the
/// server refused something the role can't do, or the app came back to the
/// screen. An owner may have changed the role on another phone meanwhile.
/// `meProvider` watches it.
final roleCheckProvider = NotifierProvider<RoleCheckNotifier, int>(
  RoleCheckNotifier.new,
);

class RoleCheckNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void again() => state++;
}

/// What the user's role in the household on screen lets them do: the one
/// place for these rules, so screens ask "may I edit?" instead of checking
/// roles. The server checks the same rules; the app hides what it would
/// refuse.
@immutable
class HouseholdPermissions {
  const HouseholdPermissions(this.role);

  /// Null while the app doesn't know the role yet: everything shows, and
  /// the server refuses what the role can't do.
  final HouseholdRole? role;

  /// Add, change and delete pets, plans, records, documents, the passport,
  /// feeding schedules, visits and supplies; scan with AI; add photos.
  /// Helpers only look and mark: fed, "Done", the visit took place, bought.
  bool get canEdit => role != HouseholdRole.helper;

  /// Invite people, change their roles, remove them, rename the group.
  bool get canManagePeople => role == HouseholdRole.owner;

  /// Take back a feeding mark or a purchase or count of a supply: helpers
  /// only their own.
  bool canTakeBack({required bool byMe}) => canEdit || byMe;

  @override
  bool operator ==(Object other) =>
      other is HouseholdPermissions && other.role == role;

  @override
  int get hashCode => role.hashCode;
}

/// What the user may do in the household on screen.
final householdPermissionsProvider = Provider<HouseholdPermissions>(
  (ref) => HouseholdPermissions(
    ref.watch(currentHouseholdProvider.select((household) => household?.role)),
  ),
);

/// For forms (a pet, a plan, a supply...): the household the form opened in.
/// Its save goes there, whichever household is on screen when Save is
/// pressed, so a form of one household can't put anything into another:
/// there its save fails. (The app shell also closes such forms on a move.)
mixin OpenedInHousehold<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  String? _openedIn;

  @override
  void initState() {
    super.initState();
    _openedIn = ref.read(currentHouseholdProvider)?.id;
  }

  /// Runs [action] (a save, a delete) with its requests naming that
  /// household.
  Future<void> inOpenedHousehold(Future<void> Function() action) =>
      inHousehold(_openedIn, action);
}
