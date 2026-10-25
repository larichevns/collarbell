import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../me/me_repository.dart' show householdRoleFromDto;
import '../me/profile_sync.dart';
import 'account.dart';

/// The person's account as a whole (spec, "Удаление аккаунта и выгрузка
/// данных"): what deleting it would do, deleting it, and downloading
/// everything of theirs.
abstract interface class AccountRepository {
  /// What deleting the account would do to each of the person's
  /// households, and the plan of it to send with the deletion.
  Future<DeletionPreview> getDeletionPreview();

  /// Deletes the account, its sign-in and the households nobody else would
  /// keep, while their fates are still [plan] (the preview the person was
  /// shown): else 409 `deletion-plan-changed`, and nothing is deleted. Only
  /// within 5 minutes of the password: else 403 `recent-sign-in-required`.
  /// Asked twice at the same moment, it is done once and both get 204; asked
  /// again after it was done, it gets 401 account-deleted (the app signs out).
  Future<void> deleteAccount(String plan);

  /// Downloads the ZIP of everything of the person's into [folder] as it
  /// comes; [onReceived] hears the bytes so far (the total isn't known).
  /// Cancelling [cancelToken] stops it and deletes what came. At most 5 an
  /// hour: then 429, with how long to wait.
  Future<ExportFile> downloadExport(
    Directory folder, {
    void Function(int received)? onReceived,
    CancelToken? cancelToken,
  });
}

/// [AccountRepository] over the API client.
class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._client);

  final ApiClient _client;

  /// The export's address. The generated `exportMe` reads the answer as
  /// text, which a ZIP isn't, so the API client downloads it into a file.
  static const exportPath = '/api/v1/me/export';

  @override
  Future<DeletionPreview> getDeletionPreview() async {
    final preview = await _client.send((api) => api.me.getAccountDeletion());
    return DeletionPreview(
      households: [
        for (final household in preview.households)
          householdOutcomeFromDto(household),
      ],
      plan: preview.plan,
    );
  }

  @override
  Future<void> deleteAccount(String plan) =>
      _client.send((api) => api.me.deleteMe(plan: plan));

  @override
  Future<ExportFile> downloadExport(
    Directory folder, {
    void Function(int received)? onReceived,
    CancelToken? cancelToken,
  }) async {
    var name = exportFileName(null, DateTime.now());
    await _client.download(
      exportPath,
      (headers) {
        name = exportFileName(
          headers.value('content-disposition'),
          DateTime.now(),
        );
        return '${folder.path}/$name';
      },
      onReceived: onReceived,
      cancelToken: cancelToken,
    );
    final path = '${folder.path}/$name';
    return ExportFile(path: path, name: name, bytes: await File(path).length());
  }
}

HouseholdOutcome householdOutcomeFromDto(
  dto.HouseholdDeletionOutcome household,
) => HouseholdOutcome(
  id: household.id,
  name: household.name,
  role: householdRoleFromDto(household.role),
  fate: switch (household.fate) {
    dto.HouseholdFate.kept => HouseholdFate.kept,
    dto.HouseholdFate.handedOver => HouseholdFate.handedOver,
    // A fate this app doesn't know (a newer server) is told as the gravest:
    // better to warn of a deletion that won't happen than to miss one.
    dto.HouseholdFate.deleted ||
    dto.HouseholdFate.$unknown => HouseholdFate.deleted,
  },
  pets: household.pets,
  others: household.others,
  newOwner: household.newOwner,
);

/// The export's file name: the one the server suggests (`Content-Disposition:
/// attachment; filename*=UTF-8''collarbell-export-2026-10-06.zip`) when it
/// is a plain one, else the same with [today]'s date. Plain: letters,
/// digits, dots and dashes only, so the name can't lead out of the folder.
String exportFileName(String? contentDisposition, DateTime today) {
  final suggested = RegExp(
    r"""filename\*?=(?:UTF-8'')?"?([^";]+)""",
    caseSensitive: false,
  ).firstMatch(contentDisposition ?? '')?.group(1)?.trim();
  if (suggested != null && RegExp(r'^\w[\w.-]*\.zip$').hasMatch(suggested)) {
    return suggested;
  }
  return 'collarbell-export-${DateFormat('yyyy-MM-dd').format(today)}.zip';
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => ApiAccountRepository(ref.watch(apiClientProvider)),
);

/// What deleting the account would do to each household, for the delete
/// screen: loaded anew each time it opens, and when the household's people
/// or pets change (live updates). Waits for the profile sync, like the
/// screens' data.
final deletionPreviewProvider = FutureProvider.autoDispose<DeletionPreview>((
  ref,
) async {
  final repository = ref.watch(accountRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getDeletionPreview();
});
