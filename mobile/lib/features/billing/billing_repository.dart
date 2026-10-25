import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../me/profile_sync.dart';
import 'household_plan.dart';

/// The group's plan. There are no payments yet (spec 8.7): Premium is given
/// by hand in the admin, and the app only shows what the group has.
abstract interface class BillingRepository {
  /// The plan of the group on screen, and this month's AI photos.
  Future<HouseholdPlan> getPlan();
}

/// [BillingRepository] over the generated API client.
class ApiBillingRepository implements BillingRepository {
  ApiBillingRepository(this._client);

  final ApiClient _client;

  @override
  Future<HouseholdPlan> getPlan() async =>
      householdPlanFromDto(await _client.send((api) => api.plan.getPlan()));
}

HouseholdPlan householdPlanFromDto(dto.PlanResponse plan) => HouseholdPlan(
  kind: plan.plan == dto.PlanKind.premium ? PlanKind.premium : PlanKind.free,
  // Moments: shown as the days they are on this phone.
  expiresAt: plan.expiresAt?.toLocal(),
  aiPhotosPerMonth: plan.aiPhotosPerMonth,
  aiPhotosUsed: plan.aiPhotosUsed,
  resetsAt: plan.resetsAt.toLocal(),
  premiumAiPhotosPerMonth: plan.premiumAiPhotosPerMonth,
);

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => ApiBillingRepository(ref.watch(apiClientProvider)),
);

/// The plan of the group on screen. Waits for the profile sync, so it loads
/// anew with every screen: after a switch to another group, and when the
/// server answers again.
final householdPlanProvider = FutureProvider.autoDispose<HouseholdPlan>((
  ref,
) async {
  final repository = ref.watch(billingRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getPlan();
});
