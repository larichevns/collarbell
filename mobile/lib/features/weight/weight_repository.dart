import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../me/profile_sync.dart';
import 'weight.dart';

/// A pet's weight log. Every method throws ApiException on failure; a pet or
/// weighing of another household is "not found". Only weighings change
/// here: a vet's weight changes in its care record.
abstract interface class WeightRepository {
  /// The pet's weighings and the weights noted at its check-ups, newest
  /// first.
  Future<List<WeightEntry>> getLog(String petId);

  /// [requestId] is a new id per weighing the user adds, the same on every
  /// retry, so a retry after a lost response doesn't add it twice.
  Future<WeightEntry> createWeighing(
    String petId,
    WeighingInput input, {
    required String requestId,
  });

  Future<WeightEntry> updateWeighing(String id, WeighingInput input);

  Future<void> deleteWeighing(String id);
}

/// [WeightRepository] over the generated API client.
class ApiWeightRepository implements WeightRepository {
  ApiWeightRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<WeightEntry>> getLog(String petId) async {
    final weights = await _client.send(
      (api) => api.weight.listPetWeights(petId: petId),
    );
    // The server sends them newest first; sorted again all the same, so the
    // changes and the chart never depend on it.
    return [for (final weight in weights) weightEntryFromDto(weight)]
      ..sort(newestFirst);
  }

  @override
  Future<WeightEntry> createWeighing(
    String petId,
    WeighingInput input, {
    required String requestId,
  }) async => weightEntryFromDto(
    await _client.send(
      (api) => api.weight.createWeight(
        petId: petId,
        body: _request(input, requestId: requestId),
      ),
    ),
  );

  @override
  Future<WeightEntry> updateWeighing(String id, WeighingInput input) async =>
      weightEntryFromDto(
        await _client.send(
          (api) => api.weight.updateWeight(
            id: id,
            // The request id is for adding only.
            body: _request(input, requestId: null),
          ),
        ),
      );

  @override
  Future<void> deleteWeighing(String id) =>
      _client.send((api) => api.weight.deleteWeight(id: id));

  static dto.WeightRequest _request(
    WeighingInput input, {
    required String? requestId,
  }) => dto.WeightRequest(
    measuredOn: input.measuredOn,
    weightKg: input.weightKg,
    bcs: input.bodyCondition?.score,
    bcsScale: input.bodyCondition?.scale,
    note: input.note,
    requestId: requestId,
  );
}

/// Values this app doesn't know yet (from a newer server) never crash it: a
/// new source is shown as a weight that can't be opened, a score on a new
/// scale as it is. Such entries are marked `hasUnknownValues` and aren't
/// edited, because saving would replace what the app can't show.
WeightEntry weightEntryFromDto(dto.WeightResponse weight) {
  final source = switch (weight.source) {
    dto.WeightSource.weighing => WeightSource.weighing,
    dto.WeightSource.careRecord => WeightSource.careRecord,
    dto.WeightSource.$unknown => WeightSource.other,
  };
  final score = weight.bcs;
  final scale = weight.bcsScale;
  final bodyCondition = score == null || scale == null
      ? null
      : BodyCondition(score, scale);
  final date = weight.measuredOn;
  return WeightEntry(
    id: weight.id,
    petId: weight.petId,
    source: source,
    // The API's dates are calendar dates.
    measuredOn: DateTime(date.year, date.month, date.day),
    weightKg: weight.weightKg,
    bodyCondition: bodyCondition,
    note: weight.note,
    createdAt: weight.createdAt,
    hasUnknownValues:
        source == WeightSource.other ||
        (score == null) != (scale == null) ||
        (bodyCondition != null && !bodyCondition.isKnown),
  );
}

// --- Providers --------------------------------------------------------------

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => ApiWeightRepository(ref.watch(apiClientProvider)),
);

/// The weight log of one pet, newest first, for its Weight tab and the
/// weight on its Overview.
final weightLogProvider = FutureProvider.autoDispose
    .family<List<WeightEntry>, String>((ref, petId) async {
      final repository = ref.watch(weightRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getLog(petId);
    });
