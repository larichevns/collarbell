import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../household/household.dart';

/// The current user's profile (`/api/v1/me`).
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.locale,
    required this.timeZone,
    required this.household,
    this.households = const [],
    this.email,
    this.displayName,
  });

  final String id;
  final String? email;
  final String? displayName;

  /// `en` or `ru`.
  final String locale;

  /// IANA time zone, e.g. `Europe/Berlin`.
  final String timeZone;

  /// The household of the request: the one it named, else the user's first.
  final Household household;

  /// Every household the user is in, the first-joined first.
  final List<HouseholdSummary> households;
}

abstract interface class MeRepository {
  /// Creates the user and their household on the first call.
  Future<UserProfile> getMe();

  /// Updates the given fields; null fields stay unchanged.
  Future<UserProfile> updateMe({
    String? displayName,
    String? locale,
    String? timeZone,
  });
}

/// [MeRepository] over the generated API client.
class ApiMeRepository implements MeRepository {
  ApiMeRepository(this._client);

  final ApiClient _client;

  @override
  Future<UserProfile> getMe() async =>
      _toProfile(await _client.send((api) => api.me.getMe()));

  @override
  Future<UserProfile> updateMe({
    String? displayName,
    String? locale,
    String? timeZone,
  }) async {
    // The server leaves null fields unchanged.
    final request = dto.UpdateMeRequest(
      displayName: displayName,
      locale: locale,
      timeZone: timeZone,
    );
    return _toProfile(
      await _client.send((api) => api.me.updateMe(body: request)),
    );
  }

  static UserProfile _toProfile(dto.MeResponse me) => UserProfile(
    id: me.id,
    email: me.email,
    displayName: me.displayName,
    locale: me.locale,
    timeZone: me.timeZone,
    household: Household(
      id: me.household.id,
      name: me.household.name,
      timeZone: me.household.timeZone,
      role: householdRoleFromDto(me.household.role),
    ),
    households: [
      for (final household in me.households) householdSummaryFromDto(household),
    ],
  );
}

/// A role the app doesn't know (a newer server) counts as the one that can
/// do the least.
HouseholdRole householdRoleFromDto(dto.HouseholdRole role) => switch (role) {
  dto.HouseholdRole.owner => HouseholdRole.owner,
  dto.HouseholdRole.member => HouseholdRole.member,
  dto.HouseholdRole.helper ||
  dto.HouseholdRole.$unknown => HouseholdRole.helper,
};

HouseholdSummary householdSummaryFromDto(dto.HouseholdSummary household) =>
    HouseholdSummary(
      id: household.id,
      name: household.name,
      role: householdRoleFromDto(household.role),
      timeZone: household.timeZone,
      memberCount: household.memberCount,
    );

final meRepositoryProvider = Provider<MeRepository>(
  (ref) => ApiMeRepository(ref.watch(apiClientProvider)),
);
