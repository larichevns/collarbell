// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/change_member_role_request.dart';
import '../models/create_household_request.dart';
import '../models/create_invite_request.dart';
import '../models/household_details.dart';
import '../models/household_invite_response.dart';
import '../models/household_summary.dart';
import '../models/invite_code_request.dart';
import '../models/invite_preview.dart';
import '../models/update_household_request.dart';

part 'households_client.g.dart';

@RestApi()
abstract class HouseholdsClient {
  factory HouseholdsClient(Dio dio, {String? baseUrl}) = _HouseholdsClient;

  /// The households the user is in, with their role in each. The app names the one it shows in the X-Household header of every request; without it, the first one.
  @GET('/api/v1/households')
  Future<List<HouseholdSummary>> listHouseholds();

  /// A new household with the user as its owner, e.g. "Office". 409 household-limit.
  @POST('/api/v1/households')
  Future<HouseholdSummary> createHouseholdGroup({
    @Body() required CreateHouseholdRequest body,
  });

  /// The household of this request: its people and their roles; for owners also the open invites.
  @GET('/api/v1/households/current')
  Future<HouseholdDetails> getCurrentHousehold();

  /// Rename the household or set its time zone (feeding times and reminders are in it). Owners only.
  @PUT('/api/v1/households/current')
  Future<HouseholdDetails> updateCurrentHousehold({
    @Body() required UpdateHouseholdRequest body,
  });

  /// Delete a household made by mistake: only an empty one (no pets, supplies or files) of one person. 409 household-not-empty. Owners only.
  @DELETE('/api/v1/households/current')
  Future<void> deleteCurrentHousehold();

  /// Give someone another role. Owners only; 409 last-owner when the household would be left without one.
  @PUT('/api/v1/households/current/members/{userId}')
  Future<HouseholdDetails> changeHouseholdMemberRole({
    @Path('userId') required String userId,
    @Body() required ChangeMemberRoleRequest body,
  });

  /// Leave the household (your own id), or, as an owner, remove someone. 409 last-owner for the last owner.
  @DELETE('/api/v1/households/current/members/{userId}')
  Future<void> removeHouseholdMember({
    @Path('userId') required String userId,
  });

  /// A one-time code to join this household as a member or a helper, valid for 7 days. Owners only. 409 invite-limit.
  @POST('/api/v1/households/current/invites')
  Future<HouseholdInviteResponse> createHouseholdInvite({
    @Body() required CreateInviteRequest body,
  });

  /// Take an invite back before someone uses it. Owners only.
  @DELETE('/api/v1/households/current/invites/{id}')
  Future<void> revokeHouseholdInvite({
    @Path('id') required String id,
  });

  /// What a code invites to: the household, who invites and the role. 404 when it's wrong, used, taken back or expired.
  @POST('/api/v1/invites/preview')
  Future<InvitePreview> previewHouseholdInvite({
    @Body() required InviteCodeRequest body,
  });

  /// Join the household of the code with its role. 404 when the code is wrong, used, taken back or expired; 409 already-a-member or household-limit. Safe to repeat.
  @POST('/api/v1/invites/accept')
  Future<HouseholdSummary> acceptHouseholdInvite({
    @Body() required InviteCodeRequest body,
  });
}
