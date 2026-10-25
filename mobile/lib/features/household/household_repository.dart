import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../me/me_repository.dart'
    show householdRoleFromDto, householdSummaryFromDto;
import '../me/profile_sync.dart';
import 'current_household.dart';
import 'household.dart';

/// The households of the user and their people (spec, "Семья"). The
/// changes name the household they are for ([householdId]), so a screen
/// left open while the app moved to another household can't change that
/// one: the server answers for the household a request names.
abstract interface class HouseholdRepository {
  /// A new household with the user as its owner, e.g. "Office".
  Future<HouseholdSummary> createHousehold(String name);

  /// The household on screen: its people and, for owners, the open invites.
  Future<HouseholdDetails> getCurrent();

  /// Owners only.
  Future<HouseholdDetails> rename(String householdId, String name);

  /// Owners only; the last owner can't stop being one (409).
  Future<HouseholdDetails> changeRole(
    String householdId,
    String userId,
    HouseholdRole role,
  );

  /// Removes someone (owners), or, with the user's own id, leaves.
  Future<void> removeMember(String householdId, String userId);

  /// Deletes the household: owners alone in it, without pets, supplies and
  /// files.
  Future<void> delete(String householdId);

  /// A one-time code for a member or a helper, valid for 7 days. Owners only.
  Future<HouseholdInvite> createInvite(String householdId, HouseholdRole role);

  Future<void> revokeInvite(String householdId, String inviteId);

  /// What [code] invites to; 404 when it's wrong, used, taken back or
  /// expired.
  Future<InvitePreview> previewInvite(String code);

  /// Joins the household of [code] with its role.
  Future<HouseholdSummary> acceptInvite(String code);
}

/// [HouseholdRepository] over the generated API client.
class ApiHouseholdRepository implements HouseholdRepository {
  ApiHouseholdRepository(this._client);

  final ApiClient _client;

  @override
  Future<HouseholdSummary> createHousehold(String name) async =>
      householdSummaryFromDto(
        await _client.send(
          (api) => api.households.createHouseholdGroup(
            body: dto.CreateHouseholdRequest(name: name),
          ),
        ),
      );

  @override
  Future<HouseholdDetails> getCurrent() async => householdDetailsFromDto(
    await _client.send((api) => api.households.getCurrentHousehold()),
  );

  @override
  Future<HouseholdDetails> rename(String householdId, String name) async =>
      householdDetailsFromDto(
        await _client.send(
          (api) => api.households.updateCurrentHousehold(
            // The server leaves the time zone as it is.
            body: dto.UpdateHouseholdRequest(name: name, timeZone: null),
          ),
          household: householdId,
        ),
      );

  @override
  Future<HouseholdDetails> changeRole(
    String householdId,
    String userId,
    HouseholdRole role,
  ) async => householdDetailsFromDto(
    await _client.send(
      (api) => api.households.changeHouseholdMemberRole(
        userId: userId,
        body: dto.ChangeMemberRoleRequest(role: householdRoleToDto(role)),
      ),
      household: householdId,
    ),
  );

  @override
  Future<void> removeMember(String householdId, String userId) => _client.send(
    (api) => api.households.removeHouseholdMember(userId: userId),
    household: householdId,
  );

  @override
  Future<void> delete(String householdId) => _client.send(
    (api) => api.households.deleteCurrentHousehold(),
    household: householdId,
  );

  @override
  Future<HouseholdInvite> createInvite(
    String householdId,
    HouseholdRole role,
  ) async => householdInviteFromDto(
    await _client.send(
      (api) => api.households.createHouseholdInvite(
        body: dto.CreateInviteRequest(role: householdRoleToDto(role)),
      ),
      household: householdId,
    ),
  );

  @override
  Future<void> revokeInvite(String householdId, String inviteId) =>
      _client.send(
        (api) => api.households.revokeHouseholdInvite(id: inviteId),
        household: householdId,
      );

  // The code goes in the body, not the address: addresses end up in logs.
  @override
  Future<InvitePreview> previewInvite(String code) async {
    final preview = await _client.send(
      (api) => api.households.previewHouseholdInvite(
        body: dto.InviteCodeRequest(code: code),
      ),
    );
    return InvitePreview(
      householdName: preview.householdName,
      invitedBy: preview.invitedBy,
      role: householdRoleFromDto(preview.role),
      expiresAt: preview.expiresAt.toLocal(),
      alreadyMember: preview.alreadyMember,
    );
  }

  @override
  Future<HouseholdSummary> acceptInvite(String code) async =>
      householdSummaryFromDto(
        await _client.send(
          (api) => api.households.acceptHouseholdInvite(
            body: dto.InviteCodeRequest(code: code),
          ),
        ),
      );
}

dto.HouseholdRole householdRoleToDto(HouseholdRole role) => switch (role) {
  HouseholdRole.owner => dto.HouseholdRole.owner,
  HouseholdRole.member => dto.HouseholdRole.member,
  HouseholdRole.helper => dto.HouseholdRole.helper,
};

HouseholdDetails householdDetailsFromDto(dto.HouseholdDetails household) =>
    HouseholdDetails(
      id: household.id,
      name: household.name,
      timeZone: household.timeZone,
      role: householdRoleFromDto(household.role),
      members: [
        for (final member in household.members)
          HouseholdMember(
            userId: member.userId,
            displayName: member.displayName,
            email: member.email,
            role: householdRoleFromDto(member.role),
            joinedAt: member.joinedAt.toLocal(),
            isMe: member.isMe,
          ),
      ],
      invites: [
        for (final invite in household.invites) householdInviteFromDto(invite),
      ],
    );

HouseholdInvite householdInviteFromDto(dto.HouseholdInviteResponse invite) =>
    HouseholdInvite(
      id: invite.id,
      code: invite.code,
      role: householdRoleFromDto(invite.role),
      createdAt: invite.createdAt.toLocal(),
      expiresAt: invite.expiresAt.toLocal(),
    );

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => ApiHouseholdRepository(ref.watch(apiClientProvider)),
);

/// The household on screen with its people, for the group screen. Waits
/// for the profile sync like every screen's data, so it reloads with them
/// (another household picked, the server back); its answer keeps the name
/// and the user's role up to date.
final householdDetailsProvider = FutureProvider.autoDispose<HouseholdDetails>((
  ref,
) async {
  final repository = ref.watch(householdRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  final details = await repository.getCurrent();
  if (ref.mounted) {
    ref.read(currentHouseholdProvider.notifier).refresh(details.household);
  }
  return details;
});
