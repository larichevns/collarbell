// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/account_deletion_preview.dart';
import '../models/me_response.dart';
import '../models/update_me_request.dart';

part 'me_client.g.dart';

@RestApi()
abstract class MeClient {
  factory MeClient(Dio dio, {String? baseUrl}) = _MeClient;

  /// The signed-in user, the household of this request and all their households. The first call creates the user and a household.
  @GET('/api/v1/me')
  Future<MeResponse> getMe();

  /// Change the display name, language or time zone.
  @PUT('/api/v1/me')
  Future<MeResponse> updateMe({
    @Body() required UpdateMeRequest body,
  });

  /// Delete the account, its sign-in and the households nobody else would keep, if the households' fates are still the plan from GET /me/deletion (else 409 deletion-plan-changed). Needs a sign-in in the last 5 minutes: 403 recent-sign-in-required.
  @DELETE('/api/v1/me')
  Future<void> deleteMe({
    @Query('plan') required String plan,
  });

  /// What deleting the account would do to each household: deleted with everything in it, kept by the others, or handed over to a member.
  @GET('/api/v1/me/deletion')
  Future<AccountDeletionPreview> getAccountDeletion();

  /// Everything of the user's as a ZIP: account.json, and each household's household.json with its photos and scans.
  @GET('/api/v1/me/export')
  @DioResponseType(ResponseType.stream)
  Stream<String> exportMe();
}
