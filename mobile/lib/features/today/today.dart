import 'package:flutter/foundation.dart';

import '../care/care.dart';
import '../feeding/feeding.dart';
import '../files/stored_file.dart';
import '../supplies/supply.dart';
import '../visits/visit.dart';

/// What the Today screen shows for all active pets: today's feedings with
/// their marks, planned visits, and care that is overdue or due within the
/// next 30 days.
@immutable
class TodayOverview {
  const TodayOverview({
    required this.date,
    this.items = const [],
    this.feedings = const [],
    this.visits = const [],
    this.shopping = const [],
  });

  /// "Today" in the household's time zone; the items count days from it.
  final DateTime date;

  /// The care that is due, soonest first.
  final List<TodayCareItem> items;

  /// Today's feedings, earliest first.
  final List<TodayFeeding> feedings;

  /// Planned visits: past ones waiting to be marked, then the coming ones.
  final List<TodayVisit> visits;

  /// Supplies to buy now, the first to run out first.
  final List<TodaySupply> shopping;

  /// How far ahead the screen looks (the server's window).
  static const windowDays = 30;

  bool get isEmpty =>
      items.isEmpty && feedings.isEmpty && visits.isEmpty && shopping.isEmpty;
}

/// A plan that is due, with the pet it belongs to.
@immutable
class TodayCareItem {
  const TodayCareItem({
    required this.planId,
    required this.petId,
    required this.petName,
    required this.kind,
    required this.title,
    required this.nextDueOn,
    required this.status,
    required this.daysLeft,
    this.petPhoto,
  });

  final String planId;
  final String petId;
  final String petName;
  final StoredFile? petPhoto;
  final CareKind kind;
  final String title;
  final DateTime nextDueOn;
  final CareStatus status;

  /// Negative when overdue.
  final int daysLeft;

  @override
  String toString() => 'TodayCareItem($petName, $title, $daysLeft)';
}

/// The groups of the Today screen, in this order.
enum TodayGroup {
  overdue,

  /// Within 14 days.
  dueSoon,

  /// The rest of the 30 days: "Later this month".
  later,
}

/// The items by group, each keeping the server's order (soonest first);
/// empty groups are left out.
Map<TodayGroup, List<TodayCareItem>> groupTodayItems(
  List<TodayCareItem> items,
) {
  TodayGroup groupOf(TodayCareItem item) => switch (item.status) {
    CareStatus.overdue => TodayGroup.overdue,
    CareStatus.dueSoon => TodayGroup.dueSoon,
    CareStatus.upcoming || CareStatus.inactive => TodayGroup.later,
  };
  return {
    for (final group in TodayGroup.values)
      if (items.any((item) => groupOf(item) == group))
        group: [
          for (final item in items)
            if (groupOf(item) == group) item,
        ],
  };
}
