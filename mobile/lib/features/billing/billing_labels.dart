import '../../l10n/l10n.dart';
import 'household_plan.dart';

/// The plan's name: Free or Premium, the same in every language.
String planKindName(AppLocalizations l10n, PlanKind kind) => switch (kind) {
  PlanKind.free => l10n.householdPlanFree,
  PlanKind.premium => l10n.householdPlanPremium,
};

/// How long Premium lasts: "Until December 31, 2026" or "No end date"; null
/// for Free.
String? planEnds(AppLocalizations l10n, HouseholdPlan plan) {
  if (!plan.premium) return null;
  final expiresAt = plan.expiresAt;
  return expiresAt == null
      ? l10n.householdPlanNoEnd
      : l10n.householdPlanUntil(expiresAt);
}
