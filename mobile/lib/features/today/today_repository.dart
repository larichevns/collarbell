import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_providers.dart';
import '../care/care_repository.dart';
import '../care/care_rules.dart';
import '../feeding/feeding.dart';
import '../feeding/feeding_repository.dart';
import '../files/files_repository.dart';
import '../me/profile_sync.dart';
import '../supplies/supplies_repository.dart';
import '../supplies/supply.dart';
import '../visits/visit.dart';
import '../visits/visits_repository.dart';
import 'today.dart';

abstract interface class TodayRepository {
  /// Today's feedings, planned visits, and care due today and in the next
  /// 30 days (overdue care included), for all active pets. Throws
  /// ApiException.
  Future<TodayOverview> getToday();
}

/// [TodayRepository] over the generated API client.
class ApiTodayRepository implements TodayRepository {
  ApiTodayRepository(this._client);

  final ApiClient _client;

  @override
  Future<TodayOverview> getToday() async {
    // No date: the server takes today in the household's time zone.
    final today = await _client.send((api) => api.today.getToday());
    return TodayOverview(
      date: DateTime(today.date.year, today.date.month, today.date.day),
      feedings: [
        for (final item in today.feedings)
          TodayFeeding(
            routineId: item.routineId,
            petId: item.petId,
            petName: item.petName,
            petPhoto: item.petPhoto == null
                ? null
                : storedFileFromDto(item.petPhoto!),
            time: timeFromDto(item.time) ?? const TimeOfDay(hour: 0, minute: 0),
            food: item.food,
            amount: item.amount,
            unit: portionUnitFromDto(item.unit),
            mark: item.mark == null ? null : feedingMarkFromDto(item.mark!),
          ),
      ],
      visits: [
        for (final item in today.appointments)
          TodayVisit(
            id: item.id,
            type: visitTypeFromDto(item.type) ?? VisitType.other,
            title: item.title,
            date: DateTime(item.date.year, item.date.month, item.date.day),
            time: timeFromDto(item.time) ?? const TimeOfDay(hour: 0, minute: 0),
            daysAway: item.daysAway,
            location: item.location,
            pets: [
              for (final pet in item.pets)
                TodayVisitPet(
                  id: pet.id,
                  name: pet.name,
                  photo: pet.photo == null
                      ? null
                      : storedFileFromDto(pet.photo!),
                ),
            ],
          ),
      ],
      shopping: [
        for (final item in today.shopping)
          if ((
                supplyCategoryFromDto(item.category),
                supplyUnitFromDto(item.unit),
                supplyStatusFromDto(item.status),
              )
              case (final category?, final unit?, final status?))
            TodaySupply(
              id: item.id,
              name: item.name,
              brand: item.brand,
              category: category,
              unit: unit,
              packageSize: item.packageSize,
              status: status,
              remaining: item.remaining,
              daysLeft: item.daysLeft,
              runsOutOn: item.runsOutOn,
            ),
      ],
      items: [
        for (final item in today.care)
          TodayCareItem(
            planId: item.planId,
            petId: item.petId,
            petName: item.petName,
            petPhoto: item.petPhoto == null
                ? null
                : storedFileFromDto(item.petPhoto!),
            kind: careKindFromDto(item.kind),
            title: item.title,
            nextDueOn: DateTime(
              item.nextDueOn.year,
              item.nextDueOn.month,
              item.nextDueOn.day,
            ),
            // Every plan on Today is active.
            status:
                careStatusFromDto(item.status) ??
                statusFor(active: true, daysLeft: item.daysLeft),
            daysLeft: item.daysLeft,
          ),
      ],
    );
  }
}

final todayRepositoryProvider = Provider<TodayRepository>(
  (ref) => ApiTodayRepository(ref.watch(apiClientProvider)),
);

/// The Today screen's feedings, visits and care. Changes refresh it (see
/// `refreshCare`, and the feeding and visit screens).
final todayProvider = FutureProvider.autoDispose<TodayOverview>((ref) async {
  final repository = ref.watch(todayRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getToday();
});
