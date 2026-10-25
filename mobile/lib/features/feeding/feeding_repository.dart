import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../care/care_repository.dart' show timeFromDto;
import '../me/profile_sync.dart';
import 'feeding.dart';

/// Feeding schedules and "fed" marks. Every method throws ApiException on
/// failure; a schedule of another household is "not found".
abstract interface class FeedingRepository {
  /// The pet's schedules, active ones first.
  Future<List<FeedingSchedule>> getSchedules(String petId);

  Future<FeedingSchedule> getSchedule(String id);

  /// [requestId] is a new id per schedule the user adds, the same on every
  /// retry, so a retry after a lost response doesn't add it twice.
  Future<FeedingSchedule> createSchedule(
    String petId,
    FeedingInput input, {
    required String requestId,
  });

  Future<FeedingSchedule> updateSchedule(String id, FeedingInput input);

  /// Its marks go too.
  Future<void> deleteSchedule(String id);

  /// Marks the feeding at [time] on [date] as fed (or [skipped]). Marking
  /// again what the same person marked returns the first mark; when
  /// someone else marked it first, throws [FeedingAlreadyMarked].
  Future<FeedingMark> mark(
    String routineId,
    DateTime date,
    TimeOfDay time, {
    bool skipped = false,
  });

  /// Takes a mark back. A mark that is gone already is no error.
  Future<void> undo(String routineId, String markId);
}

/// [FeedingRepository] over the generated API client.
class ApiFeedingRepository implements FeedingRepository {
  ApiFeedingRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<FeedingSchedule>> getSchedules(String petId) async => [
    for (final routine in await _client.send(
      (api) => api.feeding.listPetRoutines(petId: petId),
    ))
      feedingScheduleFromDto(routine),
  ];

  @override
  Future<FeedingSchedule> getSchedule(String id) async =>
      feedingScheduleFromDto(
        await _client.send((api) => api.feeding.getRoutine(id: id)),
      );

  @override
  Future<FeedingSchedule> createSchedule(
    String petId,
    FeedingInput input, {
    required String requestId,
  }) async => feedingScheduleFromDto(
    await _client.send(
      (api) => api.feeding.createRoutine(
        petId: petId,
        body: _request(input, requestId: requestId),
      ),
    ),
  );

  @override
  Future<FeedingSchedule> updateSchedule(String id, FeedingInput input) async =>
      feedingScheduleFromDto(
        await _client.send(
          (api) => api.feeding.updateRoutine(
            id: id,
            body: _request(input, requestId: null),
          ),
        ),
      );

  @override
  Future<void> deleteSchedule(String id) =>
      _client.send((api) => api.feeding.deleteRoutine(id: id));

  @override
  Future<FeedingMark> mark(
    String routineId,
    DateTime date,
    TimeOfDay time, {
    bool skipped = false,
  }) async {
    try {
      return feedingMarkFromDto(
        await _client.send(
          (api) => api.feeding.completeRoutine(
            id: routineId,
            body: dto.CompleteRoutineRequest(
              date: date,
              time: timeToDto(time),
              status: skipped
                  ? dto.CompletionStatus.skipped
                  : dto.CompletionStatus.done,
            ),
          ),
        ),
      );
    } on ApiException catch (error) {
      // 409: someone else marked it; the body says who and when.
      final body =
          error.kind == ApiErrorKind.conflict && error.cause is DioException
          ? (error.cause! as DioException).response?.data
          : null;
      FeedingMark? first;
      if (body is Map<String, Object?>) {
        try {
          first = feedingMarkFromDto(
            dto.RoutineCompletionResponse.fromJson(body),
          );
        } catch (_) {
          // Not a mark (e.g. a problem description): the conflict as it is.
        }
      }
      if (first != null) throw FeedingAlreadyMarked(first);
      rethrow;
    }
  }

  @override
  Future<void> undo(String routineId, String markId) async {
    try {
      await _client.send(
        (api) => api.feeding.undoRoutineCompletion(
          id: routineId,
          completionId: markId,
        ),
      );
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.notFound) rethrow;
    }
  }

  static dto.RoutineRequest _request(
    FeedingInput input, {
    required String? requestId,
  }) => dto.RoutineRequest(
    kind: dto.RoutineKind.feeding,
    times: [for (final time in input.times) timeToDto(time)],
    days: [for (final day in input.days) _dayToDto(day)],
    food: input.food,
    amount: input.amount,
    unit: input.amount == null ? null : _unitToDto(input.unit),
    notes: input.notes,
    active: input.active,
    requestId: requestId,
    supplyItemId: input.supplyItemId,
  );
}

FeedingSchedule feedingScheduleFromDto(dto.RoutineResponse routine) {
  final days = [for (final day in routine.days) ?_dayFromDto(day)]..sort();
  final unit = portionUnitFromDto(routine.unit);
  return FeedingSchedule(
    id: routine.id,
    petId: routine.petId,
    times: [for (final time in routine.times) ?timeFromDto(time)],
    days: days,
    food: routine.food,
    amount: routine.amount,
    unit: unit,
    notes: routine.notes,
    active: routine.active,
    supplyItemId: routine.supplyItemId,
    hasUnknownValues:
        routine.kind != dto.RoutineKind.feeding ||
        days.length != routine.days.length ||
        (routine.unit != null && unit == null),
  );
}

FeedingMark feedingMarkFromDto(dto.RoutineCompletionResponse mark) =>
    FeedingMark(
      id: mark.id,
      routineId: mark.routineId,
      date: DateTime(mark.date.year, mark.date.month, mark.date.day),
      time: timeFromDto(mark.time) ?? const TimeOfDay(hour: 0, minute: 0),
      skipped: mark.status == dto.CompletionStatus.skipped,
      doneAt: mark.doneAt.toLocal(),
      byName: mark.byName,
      byMe: mark.byMe,
    );

PortionUnit? portionUnitFromDto(dto.PortionUnit? unit) => switch (unit) {
  dto.PortionUnit.gram => PortionUnit.gram,
  dto.PortionUnit.milliliter => PortionUnit.milliliter,
  dto.PortionUnit.piece => PortionUnit.piece,
  _ => null,
};

dto.PortionUnit? _unitToDto(PortionUnit? unit) => switch (unit) {
  PortionUnit.gram => dto.PortionUnit.gram,
  PortionUnit.milliliter => dto.PortionUnit.milliliter,
  PortionUnit.piece => dto.PortionUnit.piece,
  null => null,
};

int? _dayFromDto(dto.DayOfWeek day) => switch (day) {
  dto.DayOfWeek.monday => DateTime.monday,
  dto.DayOfWeek.tuesday => DateTime.tuesday,
  dto.DayOfWeek.wednesday => DateTime.wednesday,
  dto.DayOfWeek.thursday => DateTime.thursday,
  dto.DayOfWeek.friday => DateTime.friday,
  dto.DayOfWeek.saturday => DateTime.saturday,
  dto.DayOfWeek.sunday => DateTime.sunday,
  dto.DayOfWeek.$unknown => null,
};

dto.DayOfWeek _dayToDto(int day) => switch (day) {
  DateTime.monday => dto.DayOfWeek.monday,
  DateTime.tuesday => dto.DayOfWeek.tuesday,
  DateTime.wednesday => dto.DayOfWeek.wednesday,
  DateTime.thursday => dto.DayOfWeek.thursday,
  DateTime.friday => dto.DayOfWeek.friday,
  DateTime.saturday => dto.DayOfWeek.saturday,
  _ => dto.DayOfWeek.sunday,
};

/// The API takes times as `08:00:00`.
String timeToDto(TimeOfDay time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:00';
}

// --- Providers --------------------------------------------------------------

final feedingRepositoryProvider = Provider<FeedingRepository>(
  (ref) => ApiFeedingRepository(ref.watch(apiClientProvider)),
);

/// The feeding schedules of one pet, for its Feeding tab.
final feedingSchedulesProvider = FutureProvider.autoDispose
    .family<List<FeedingSchedule>, String>((ref, petId) async {
      final repository = ref.watch(feedingRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getSchedules(petId);
    });

/// One schedule, for its form.
final feedingScheduleProvider = FutureProvider.autoDispose
    .family<FeedingSchedule, String>((ref, id) async {
      final repository = ref.watch(feedingRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getSchedule(id);
    });
