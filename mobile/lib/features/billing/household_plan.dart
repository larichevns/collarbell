import 'package:flutter/foundation.dart';

/// Free or Premium (the server's `PlanKind`).
enum PlanKind { free, premium }

/// The group's plan and this month's AI photos (`GET /api/v1/plan`). A plan
/// belongs to the group: everyone in it has the same one, helpers too.
@immutable
class HouseholdPlan {
  const HouseholdPlan({
    required this.kind,
    this.expiresAt,
    required this.aiPhotosPerMonth,
    required this.aiPhotosUsed,
    required this.resetsAt,
    required this.premiumAiPhotosPerMonth,
  });

  final PlanKind kind;

  /// When Premium ends, on the phone's clock; null: no end, or Free.
  final DateTime? expiresAt;

  /// The AI photos this plan allows a month.
  final int aiPhotosPerMonth;

  /// AI photos this month, with those of passport scans still being read.
  final int aiPhotosUsed;

  /// When the count starts again (the first of next month, UTC), on the
  /// phone's clock: its date is shown.
  final DateTime resetsAt;

  /// What Premium allows, to tell about it on Free.
  final int premiumAiPhotosPerMonth;

  bool get premium => kind == PlanKind.premium;

  /// The month's AI photos are all used.
  bool get aiPhotosUsedUp => aiPhotosUsed >= aiPhotosPerMonth;
}
