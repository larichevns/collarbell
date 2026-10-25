import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../care/care.dart';
import '../care/care_repository.dart' show careKindToDto, timeFromDto;
import '../feeding/feeding_repository.dart' show timeToDto;
import '../me/profile_sync.dart';
import 'visit.dart';

/// Visits of the household. Every method throws ApiException on failure; a
/// visit of another household is "not found".
abstract interface class VisitsRepository {
  /// Planned visits first (soonest first), then past and cancelled ones
  /// (newest first).
  Future<List<Visit>> getVisits();

  Future<Visit> getVisit(String id);

  /// [requestId] is a new id per visit the user adds, the same on every
  /// retry, so a retry after a lost response doesn't add it twice.
  Future<Visit> createVisit(VisitInput input, {required String requestId});

  Future<Visit> updateVisit(String id, VisitInput input);

  /// Records made from it stay.
  Future<void> deleteVisit(String id);

  /// "The visit took place". With [recordKind], each pet of the visit gets
  /// a care record of that kind, and [planIds] (at most one per pet, of the
  /// same kind) count it as "Done". Done again changes nothing. Returns the
  /// visit and the plans that moved.
  Future<({Visit visit, List<String> movedPlanIds})> completeVisit(
    String id, {
    CareKind? recordKind,
    List<String> planIds = const [],
    String? notes,
  });
}

/// [VisitsRepository] over the generated API client.
class ApiVisitsRepository implements VisitsRepository {
  ApiVisitsRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Visit>> getVisits() async => [
    for (final visit in await _client.send(
      (api) => api.appointments.listAppointments(),
    ))
      visitFromDto(visit),
  ];

  @override
  Future<Visit> getVisit(String id) async => visitFromDto(
    await _client.send((api) => api.appointments.getAppointment(id: id)),
  );

  @override
  Future<Visit> createVisit(
    VisitInput input, {
    required String requestId,
  }) async => visitFromDto(
    await _client.send(
      (api) => api.appointments.createAppointment(
        body: _request(input, requestId: requestId),
      ),
    ),
  );

  @override
  Future<Visit> updateVisit(String id, VisitInput input) async => visitFromDto(
    await _client.send(
      (api) => api.appointments.updateAppointment(
        id: id,
        body: _request(input, requestId: null),
      ),
    ),
  );

  @override
  Future<void> deleteVisit(String id) =>
      _client.send((api) => api.appointments.deleteAppointment(id: id));

  @override
  Future<({Visit visit, List<String> movedPlanIds})> completeVisit(
    String id, {
    CareKind? recordKind,
    List<String> planIds = const [],
    String? notes,
  }) async {
    final result = await _client.send(
      (api) => api.appointments.completeAppointment(
        id: id,
        body: dto.CompleteAppointmentRequest(
          recordKind: recordKind == null ? null : careKindToDto(recordKind),
          planIds: planIds,
          notes: notes,
        ),
      ),
    );
    return (
      visit: visitFromDto(result.appointment),
      movedPlanIds: result.movedPlanIds,
    );
  }

  static dto.AppointmentRequest _request(
    VisitInput input, {
    required String? requestId,
  }) => dto.AppointmentRequest(
    type: _typeToDto(input.type),
    title: input.title,
    date: input.date,
    time: timeToDto(input.time),
    durationMinutes: input.durationMinutes,
    location: input.location,
    notes: input.notes,
    petIds: input.petIds,
    remindOffsetsMinutes: input.remindMinutesBefore,
    status: switch (input.status) {
      VisitStatus.planned => dto.AppointmentStatus.planned,
      VisitStatus.cancelled => dto.AppointmentStatus.cancelled,
      VisitStatus.done => dto.AppointmentStatus.done,
      null => null,
    },
    requestId: requestId,
  );
}

Visit visitFromDto(dto.AppointmentResponse visit) {
  final type = visitTypeFromDto(visit.type);
  final status = switch (visit.status) {
    dto.AppointmentStatus.planned => VisitStatus.planned,
    dto.AppointmentStatus.done => VisitStatus.done,
    dto.AppointmentStatus.cancelled => VisitStatus.cancelled,
    _ => null,
  };
  return Visit(
    id: visit.id,
    type: type ?? VisitType.other,
    title: visit.title,
    date: DateTime(visit.date.year, visit.date.month, visit.date.day),
    time: timeFromDto(visit.time) ?? const TimeOfDay(hour: 0, minute: 0),
    petIds: visit.petIds,
    remindMinutesBefore: visit.remindOffsetsMinutes,
    status: status ?? VisitStatus.planned,
    durationMinutes: visit.durationMinutes,
    location: visit.location,
    notes: visit.notes,
    recordIds: visit.recordIds,
    hasUnknownValues: type == null || status == null,
  );
}

/// Null for a type this app doesn't know.
VisitType? visitTypeFromDto(dto.AppointmentType type) => switch (type) {
  dto.AppointmentType.vet => VisitType.vet,
  dto.AppointmentType.grooming => VisitType.grooming,
  dto.AppointmentType.training => VisitType.training,
  dto.AppointmentType.other => VisitType.other,
  dto.AppointmentType.$unknown => null,
};

dto.AppointmentType _typeToDto(VisitType type) => switch (type) {
  VisitType.vet => dto.AppointmentType.vet,
  VisitType.grooming => dto.AppointmentType.grooming,
  VisitType.training => dto.AppointmentType.training,
  VisitType.other => dto.AppointmentType.other,
};

// --- Providers --------------------------------------------------------------

final visitsRepositoryProvider = Provider<VisitsRepository>(
  (ref) => ApiVisitsRepository(ref.watch(apiClientProvider)),
);

/// All visits of the household, for the visits list.
final visitsProvider = FutureProvider.autoDispose<List<Visit>>((ref) async {
  final repository = ref.watch(visitsRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getVisits();
});

/// One visit, for its page and form.
final visitProvider = FutureProvider.autoDispose.family<Visit, String>((
  ref,
  id,
) async {
  final repository = ref.watch(visitsRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getVisit(id);
});
