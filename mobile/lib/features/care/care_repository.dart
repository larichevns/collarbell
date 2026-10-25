import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../files/files_repository.dart';
import '../me/profile_sync.dart';
import '../pets/pet.dart';
import 'care.dart';
import 'care_rules.dart';

/// Care plans and records of the household's pets. Every method throws
/// ApiException on failure; a plan or record of another household is "not
/// found".
///
/// There is no way to replace a record's photo list: photos are added and
/// removed one by one, so a screen working from an old copy can never drop
/// photos it doesn't know about.
abstract interface class CareRepository {
  /// Ready-made plans that suit [species].
  Future<List<CarePreset>> getPresets(PetSpecies species);

  /// Active plans first, soonest due first.
  Future<List<CarePlan>> getPlans(String petId);

  Future<CarePlan> getPlan(String id);

  /// [requestId] is a new id per plan the user adds, the same on every
  /// retry, so a retry after a lost response doesn't add it twice.
  Future<CarePlan> createPlan(
    String petId,
    CarePlanInput input, {
    required String requestId,
  });

  /// Replaces the plan's details, including its next date.
  Future<CarePlan> updatePlan(String id, CarePlanInput input);

  /// The records the plan made stay in the history.
  Future<void> deletePlan(String id);

  /// "Done": adds a record and moves the plan to its next date (a one-off
  /// plan finishes). Photos are attached to the returned record afterwards.
  ///
  /// [requestId] is a new id per "Done" the user makes, the same on every
  /// retry: the server answers a retry after a lost response with the first
  /// result instead of marking the plan done twice.
  Future<({CarePlan plan, CareRecord record})> completePlan(
    String id,
    CompletionInput input, {
    required String requestId,
  });

  /// The pet's history, newest first.
  Future<List<CareRecord>> getRecords(String petId);

  Future<CareRecord> getRecord(String id);

  /// [requestId] is a new id per record the user adds, the same on every
  /// retry, so a retry after a lost response doesn't add it twice.
  Future<CareRecord> createRecord(
    String petId,
    CareRecordInput input, {
    required String requestId,
  });

  /// Replaces the record's details; its photos stay as they are.
  Future<CareRecord> updateRecord(String id, CareRecordInput input);

  /// Also deletes the record's photos. A plan it completed keeps its date.
  Future<void> deleteRecord(String id);

  /// Attaches one uploaded file to the record, after the ones it has. A
  /// file that is already on the record is no error, so a retry after a
  /// lost response just succeeds.
  Future<CareRecord> addRecordFile(String recordId, String fileId);

  /// Deletes one photo of the record. A photo that is already gone is not
  /// an error: a retry after a lost response must not get stuck.
  Future<void> removeRecordFile(String recordId, String fileId);

  /// The health sections of the passport (V–X), built from the records.
  Future<PassportRecords> getPassportRecords(String petId);
}

/// [CareRepository] over the generated API client.
class ApiCareRepository implements CareRepository {
  ApiCareRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<CarePreset>> getPresets(PetSpecies species) async {
    final presets = await _client.send(
      (api) => api.care.listCarePlanPresets(species: _speciesToDto(species)),
    );
    return [for (final preset in presets) ?carePresetFromDto(preset)];
  }

  @override
  Future<List<CarePlan>> getPlans(String petId) async {
    final plans = await _client.send(
      (api) => api.care.listPetCarePlans(petId: petId),
    );
    return [for (final plan in plans) carePlanFromDto(plan)];
  }

  @override
  Future<CarePlan> getPlan(String id) async => carePlanFromDto(
    await _client.send((api) => api.care.getCarePlan(id: id)),
  );

  @override
  Future<CarePlan> createPlan(
    String petId,
    CarePlanInput input, {
    required String requestId,
  }) async {
    final request = _planRequest(input, requestId: requestId);
    return carePlanFromDto(
      await _client.send(
        (api) => api.care.createCarePlan(petId: petId, body: request),
      ),
    );
  }

  @override
  Future<CarePlan> updatePlan(String id, CarePlanInput input) async {
    // The request id is for creating only.
    final request = _planRequest(input, requestId: null);
    return carePlanFromDto(
      await _client.send(
        (api) => api.care.updateCarePlan(id: id, body: request),
      ),
    );
  }

  @override
  Future<void> deletePlan(String id) =>
      _client.send((api) => api.care.deleteCarePlan(id: id));

  @override
  Future<({CarePlan plan, CareRecord record})> completePlan(
    String id,
    CompletionInput input, {
    required String requestId,
  }) async {
    final request = dto.CompleteCarePlanRequest(
      performedOn: input.performedOn,
      performedTime: _timeToDto(input.performedTime),
      product: input.product,
      manufacturer: input.manufacturer,
      batchNumber: input.batchNumber,
      validFrom: input.validFrom,
      validUntil: input.validUntil,
      clinic: input.clinic,
      veterinarian: input.veterinarian,
      notes: input.notes,
      nextDueOn: input.nextDueOn,
      requestId: requestId,
    );
    final done = await _client.send(
      (api) => api.care.completeCarePlan(id: id, body: request),
    );
    return (
      plan: carePlanFromDto(done.plan),
      record: careRecordFromDto(done.record),
    );
  }

  @override
  Future<List<CareRecord>> getRecords(String petId) async {
    final records = await _client.send(
      (api) => api.care.listPetCareRecords(petId: petId),
    );
    return [for (final record in records) careRecordFromDto(record)];
  }

  @override
  Future<CareRecord> getRecord(String id) async => careRecordFromDto(
    await _client.send((api) => api.care.getCareRecord(id: id)),
  );

  @override
  Future<CareRecord> createRecord(
    String petId,
    CareRecordInput input, {
    required String requestId,
  }) async {
    final request = careRecordRequestFromInput(input, requestId: requestId);
    return careRecordFromDto(
      await _client.send(
        (api) => api.care.createCareRecord(petId: petId, body: request),
      ),
    );
  }

  @override
  Future<CareRecord> updateRecord(String id, CareRecordInput input) async {
    // The request id is for creating only.
    final request = careRecordRequestFromInput(input, requestId: null);
    return careRecordFromDto(
      await _client.send(
        (api) => api.care.updateCareRecord(id: id, body: request),
      ),
    );
  }

  @override
  Future<void> deleteRecord(String id) =>
      _client.send((api) => api.care.deleteCareRecord(id: id));

  @override
  Future<CareRecord> addRecordFile(String recordId, String fileId) async {
    final request = dto.AddRecordFilesRequest(fileIds: [fileId]);
    return careRecordFromDto(
      await _client.send(
        (api) => api.care.addCareRecordFiles(id: recordId, body: request),
      ),
    );
  }

  @override
  Future<void> removeRecordFile(String recordId, String fileId) async {
    try {
      await _client.send(
        (api) => api.care.removeCareRecordFile(id: recordId, fileId: fileId),
      );
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.notFound) rethrow;
    }
  }

  @override
  Future<PassportRecords> getPassportRecords(String petId) async {
    final sections = await _client.send(
      (api) => api.passport.getPetPassportRecords(petId: petId),
    );
    List<CareRecord> records(List<dto.CareRecordResponse> section) => [
      for (final record in section) careRecordFromDto(record),
    ];
    return PassportRecords(
      rabies: records(sections.rabies),
      rabiesTiters: records(sections.rabiesTiters),
      echinococcus: records(sections.echinococcus),
      treatments: records(sections.treatments),
      otherVaccinations: records(sections.otherVaccinations),
      examinations: records(sections.examinations),
    );
  }

  static dto.CarePlanRequest _planRequest(
    CarePlanInput input, {
    required String? requestId,
  }) {
    final interval = input.interval;
    return dto.CarePlanRequest(
      kind: careKindToDto(input.kind),
      title: input.title,
      intervalValue: interval?.value,
      intervalUnit: interval == null ? null : _unitToDto(interval.unit),
      nextDueOn: input.nextDueOn,
      remindOffsetsDays: input.remindOffsetsDays,
      defaultProduct: input.defaultProduct,
      targets: [for (final target in input.targets) _targetToDto(target)],
      presetCode: input.presetCode,
      notes: input.notes,
      active: input.active,
      requestId: requestId,
    );
  }
}

/// The request body of a record, as the record form and the scan send it.
/// [requestId] makes adding it safe to retry; null on edits.
dto.CareRecordRequest careRecordRequestFromInput(
  CareRecordInput input, {
  required String? requestId,
}) {
  final details = input.details;
  return dto.CareRecordRequest(
    kind: careKindToDto(input.kind),
    title: input.title,
    performedOn: input.performedOn,
    performedTime: _timeToDto(input.performedTime),
    product: input.product,
    manufacturer: input.manufacturer,
    batchNumber: input.batchNumber,
    validFrom: input.validFrom,
    validUntil: input.validUntil,
    targets: [for (final target in input.targets) _targetToDto(target)],
    clinic: input.clinic,
    veterinarian: input.veterinarian,
    weightKg: input.weightKg,
    details: details.isEmpty
        ? null
        : dto.CareRecordDetailsDto(
            laboratory: details.laboratory,
            reportNumber: details.reportNumber,
            titerIuPerMl: details.titerIuPerMl,
            fitForTravel: details.fitForTravel,
          ),
    notes: input.notes,
    requestId: requestId,
  );
}

// --- Mapping ----------------------------------------------------------------
//
// Values this app doesn't know yet (from a newer server) never crash it:
// an unknown kind is shown as "other", an unknown status is worked out from
// the days left, unknown vaccine targets are left out. Plans and records
// with such values are marked `hasUnknownValues`, and the app doesn't let
// the user edit them, because saving would replace what it can't show.

/// Null for a preset the app can't offer: its kind or interval unit is
/// unknown, so a plan made from it couldn't be saved as the server meant.
CarePreset? carePresetFromDto(dto.CarePresetResponse preset) {
  if (preset.kind == dto.CareKind.$unknown) return null;
  final (interval, intervalUnknown) = _intervalFromDto(
    preset.intervalValue,
    preset.intervalUnit,
  );
  if (intervalUnknown) return null;
  return CarePreset(
    code: preset.code,
    species: switch (preset.species) {
      dto.Species.cat => PetSpecies.cat,
      dto.Species.dog => PetSpecies.dog,
      dto.Species.other => PetSpecies.other,
      null || dto.Species.$unknown => null,
    },
    kind: careKindFromDto(preset.kind),
    title: preset.title,
    interval: interval,
    targets: vaccineTargetsFromDto(preset.targets),
    dogOnly: preset.dogOnly,
    note: preset.note,
  );
}

CarePlan carePlanFromDto(dto.CarePlanResponse plan) {
  final (interval, intervalUnknown) = _intervalFromDto(
    plan.intervalValue,
    plan.intervalUnit,
  );
  return CarePlan(
    id: plan.id,
    petId: plan.petId,
    kind: careKindFromDto(plan.kind),
    title: plan.title,
    interval: interval,
    intervalUnknown: intervalUnknown,
    nextDueOn: _calendarDate(plan.nextDueOn),
    status:
        careStatusFromDto(plan.status) ??
        statusFor(active: plan.active, daysLeft: plan.daysLeft),
    daysLeft: plan.daysLeft,
    lastDoneOn: _calendarDateOrNull(plan.lastDoneOn),
    remindOffsetsDays: plan.remindOffsetsDays,
    defaultProduct: plan.defaultProduct,
    targets: vaccineTargetsFromDto(plan.targets),
    presetCode: plan.presetCode,
    notes: plan.notes,
    active: plan.active,
    hasUnknownValues:
        plan.kind == dto.CareKind.$unknown ||
        intervalUnknown ||
        plan.targets.contains(dto.VaccineTarget.$unknown),
  );
}

CareRecord careRecordFromDto(dto.CareRecordResponse record) {
  final details = record.details;
  return CareRecord(
    id: record.id,
    petId: record.petId,
    planId: record.planId,
    kind: careKindFromDto(record.kind),
    title: record.title,
    performedOn: _calendarDate(record.performedOn),
    performedTime: timeFromDto(record.performedTime),
    product: record.product,
    manufacturer: record.manufacturer,
    batchNumber: record.batchNumber,
    validFrom: _calendarDateOrNull(record.validFrom),
    validUntil: _calendarDateOrNull(record.validUntil),
    targets: vaccineTargetsFromDto(record.targets),
    clinic: record.clinic,
    veterinarian: record.veterinarian,
    weightKg: record.weightKg,
    details: details == null
        ? CareRecordDetails.empty
        : CareRecordDetails(
            laboratory: details.laboratory,
            reportNumber: details.reportNumber,
            titerIuPerMl: details.titerIuPerMl,
            fitForTravel: details.fitForTravel,
          ),
    notes: record.notes,
    source: switch (record.source) {
      dto.RecordSource.manual => RecordSource.manual,
      dto.RecordSource.aiScan => RecordSource.aiScan,
      dto.RecordSource.$unknown => null,
    },
    files: [for (final file in record.files) storedFileFromDto(file)],
    hasUnknownValues:
        record.kind == dto.CareKind.$unknown ||
        record.targets.contains(dto.VaccineTarget.$unknown),
  );
}

/// An unknown kind is shown as "other".
CareKind careKindFromDto(dto.CareKind kind) => switch (kind) {
  dto.CareKind.vaccination => CareKind.vaccination,
  dto.CareKind.rabiesTiter => CareKind.rabiesTiter,
  dto.CareKind.deworming => CareKind.deworming,
  dto.CareKind.echinococcus => CareKind.echinococcus,
  dto.CareKind.fleaTick => CareKind.fleaTick,
  dto.CareKind.heartworm => CareKind.heartworm,
  dto.CareKind.vetExam => CareKind.vetExam,
  dto.CareKind.dental => CareKind.dental,
  dto.CareKind.grooming => CareKind.grooming,
  dto.CareKind.procedure => CareKind.procedure,
  dto.CareKind.other || dto.CareKind.$unknown => CareKind.other,
};

dto.CareKind careKindToDto(CareKind kind) => switch (kind) {
  CareKind.vaccination => dto.CareKind.vaccination,
  CareKind.rabiesTiter => dto.CareKind.rabiesTiter,
  CareKind.deworming => dto.CareKind.deworming,
  CareKind.echinococcus => dto.CareKind.echinococcus,
  CareKind.fleaTick => dto.CareKind.fleaTick,
  CareKind.heartworm => dto.CareKind.heartworm,
  CareKind.vetExam => dto.CareKind.vetExam,
  CareKind.dental => dto.CareKind.dental,
  CareKind.grooming => dto.CareKind.grooming,
  CareKind.procedure => dto.CareKind.procedure,
  CareKind.other => dto.CareKind.other,
};

/// Null for a status this app doesn't know; the caller works it out.
CareStatus? careStatusFromDto(dto.CareStatus status) => switch (status) {
  dto.CareStatus.overdue => CareStatus.overdue,
  dto.CareStatus.dueSoon => CareStatus.dueSoon,
  dto.CareStatus.upcoming => CareStatus.upcoming,
  dto.CareStatus.inactive => CareStatus.inactive,
  dto.CareStatus.$unknown => null,
};

/// The interval, and whether its unit is unknown. Both values null mean a
/// one-off plan.
(CareInterval?, bool) _intervalFromDto(int? value, dto.IntervalUnit? unit) {
  if (value == null || unit == null || unit == dto.IntervalUnit.valueNull) {
    return (null, false);
  }
  final known = switch (unit) {
    dto.IntervalUnit.day => IntervalUnit.day,
    dto.IntervalUnit.week => IntervalUnit.week,
    dto.IntervalUnit.month => IntervalUnit.month,
    dto.IntervalUnit.year => IntervalUnit.year,
    dto.IntervalUnit.valueNull || dto.IntervalUnit.$unknown => null,
  };
  return known == null ? (null, true) : (CareInterval(value, known), false);
}

dto.IntervalUnit _unitToDto(IntervalUnit unit) => switch (unit) {
  IntervalUnit.day => dto.IntervalUnit.day,
  IntervalUnit.week => dto.IntervalUnit.week,
  IntervalUnit.month => dto.IntervalUnit.month,
  IntervalUnit.year => dto.IntervalUnit.year,
};

/// Unknown targets are left out.
List<VaccineTarget> vaccineTargetsFromDto(List<dto.VaccineTarget> targets) => [
  for (final target in targets) ?_targetFromDto(target),
];

VaccineTarget? _targetFromDto(dto.VaccineTarget target) => switch (target) {
  dto.VaccineTarget.rabies => VaccineTarget.rabies,
  dto.VaccineTarget.fpv => VaccineTarget.fpv,
  dto.VaccineTarget.fhv1 => VaccineTarget.fhv1,
  dto.VaccineTarget.fcv => VaccineTarget.fcv,
  dto.VaccineTarget.felv => VaccineTarget.felv,
  dto.VaccineTarget.chlamydia => VaccineTarget.chlamydia,
  dto.VaccineTarget.cdv => VaccineTarget.cdv,
  dto.VaccineTarget.cav2 => VaccineTarget.cav2,
  dto.VaccineTarget.cpv2 => VaccineTarget.cpv2,
  dto.VaccineTarget.cpiv => VaccineTarget.cpiv,
  dto.VaccineTarget.lepto => VaccineTarget.lepto,
  dto.VaccineTarget.bordetella => VaccineTarget.bordetella,
  dto.VaccineTarget.lyme => VaccineTarget.lyme,
  dto.VaccineTarget.canineInfluenza => VaccineTarget.canineInfluenza,
  dto.VaccineTarget.leishmania => VaccineTarget.leishmania,
  dto.VaccineTarget.$unknown => null,
};

dto.VaccineTarget _targetToDto(VaccineTarget target) => switch (target) {
  VaccineTarget.rabies => dto.VaccineTarget.rabies,
  VaccineTarget.fpv => dto.VaccineTarget.fpv,
  VaccineTarget.fhv1 => dto.VaccineTarget.fhv1,
  VaccineTarget.fcv => dto.VaccineTarget.fcv,
  VaccineTarget.felv => dto.VaccineTarget.felv,
  VaccineTarget.chlamydia => dto.VaccineTarget.chlamydia,
  VaccineTarget.cdv => dto.VaccineTarget.cdv,
  VaccineTarget.cav2 => dto.VaccineTarget.cav2,
  VaccineTarget.cpv2 => dto.VaccineTarget.cpv2,
  VaccineTarget.cpiv => dto.VaccineTarget.cpiv,
  VaccineTarget.lepto => dto.VaccineTarget.lepto,
  VaccineTarget.bordetella => dto.VaccineTarget.bordetella,
  VaccineTarget.lyme => dto.VaccineTarget.lyme,
  VaccineTarget.canineInfluenza => dto.VaccineTarget.canineInfluenza,
  VaccineTarget.leishmania => dto.VaccineTarget.leishmania,
};

dto.Species _speciesToDto(PetSpecies species) => switch (species) {
  PetSpecies.cat => dto.Species.cat,
  PetSpecies.dog => dto.Species.dog,
  PetSpecies.other => dto.Species.other,
};

/// The API sends times as `14:30:00`.
TimeOfDay? timeFromDto(String? time) {
  final parts = time?.split(':');
  if (parts == null || parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String? _timeToDto(TimeOfDay? time) {
  if (time == null) return null;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:00';
}

/// Drops any time part: the API's dates are calendar dates.
DateTime _calendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime? _calendarDateOrNull(DateTime? date) =>
    date == null ? null : _calendarDate(date);

// --- Providers --------------------------------------------------------------

final careRepositoryProvider = Provider<CareRepository>(
  (ref) => ApiCareRepository(ref.watch(apiClientProvider)),
);

/// The presets for one species, for the preset picker and the plan form.
final carePresetsProvider = FutureProvider.autoDispose
    .family<List<CarePreset>, PetSpecies>((ref, species) async {
      final repository = ref.watch(careRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getPresets(species);
    });

/// The plans of one pet, for its Health tab.
final carePlansProvider = FutureProvider.autoDispose
    .family<List<CarePlan>, String>((ref, petId) async {
      final repository = ref.watch(careRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getPlans(petId);
    });

/// One plan, for its form and the Done screen.
final carePlanProvider = FutureProvider.autoDispose.family<CarePlan, String>((
  ref,
  id,
) async {
  final repository = ref.watch(careRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getPlan(id);
});

/// The history of one pet, newest first.
final careRecordsProvider = FutureProvider.autoDispose
    .family<List<CareRecord>, String>((ref, petId) async {
      final repository = ref.watch(careRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getRecords(petId);
    });

/// One record, for its detail screen and form.
final careRecordProvider = FutureProvider.autoDispose
    .family<CareRecord, String>((ref, id) async {
      final repository = ref.watch(careRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getRecord(id);
    });

/// The passport's health sections of one pet.
final passportRecordsProvider = FutureProvider.autoDispose
    .family<PassportRecords, String>((ref, petId) async {
      final repository = ref.watch(careRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getPassportRecords(petId);
    });
