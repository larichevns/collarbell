import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import '../care/care_repository.dart' show careKindFromDto;
import '../feeding/feeding_repository.dart' show portionUnitFromDto;
import '../me/profile_sync.dart';
import 'supply.dart';

/// The scanned code isn't a product barcode (a QR code of a website, say).
class NotAProductCode implements Exception {
  const NotAProductCode();
}

/// Why photos of a package couldn't be read.
enum ProductScanProblem {
  /// No AI model is set up on the server.
  notConfigured,

  /// All models are busy or out of quota: try again later.
  busy,

  /// The provider refused the request.
  rejected,
}

class ProductScanFailed implements Exception {
  const ProductScanFailed(this.problem);

  final ProductScanProblem problem;

  @override
  String toString() => 'ProductScanFailed($problem)';
}

/// The household's supplies. Every method throws ApiException on failure; an
/// item of another household is "not found".
abstract interface class SuppliesRepository {
  /// What runs out first comes first, items no longer bought last.
  Future<List<Supply>> getSupplies();

  Future<Supply> getSupply(String id);

  /// [requestId] is a new id per item the user adds, the same on every
  /// retry, so a retry after a lost response doesn't add it twice.
  Future<Supply> createSupply(SupplyInput input, {required String requestId});

  Future<Supply> updateSupply(String id, SupplyInput input);

  Future<void> deleteSupply(String id);

  /// Purchases and counts, newest first.
  Future<List<StockEntry>> getStock(String supplyId);

  /// A purchase ([quantity] added) or a count ([quantity] is what is left).
  /// [requestId] is new per entry and the same on retries: a purchase isn't
  /// counted twice. Returns the item with its new estimate.
  Future<Supply> addStock(
    String supplyId,
    StockEventKind kind,
    double quantity, {
    required String requestId,
  });

  Future<void> deleteStock(String supplyId, String entryId);

  /// What a scanned [code] is. Throws [NotAProductCode] when it isn't a
  /// product barcode.
  Future<ProductLookup> lookup(String code);

  /// Reads photos of a package with AI; waits for the answer (up to a few
  /// minutes). Throws [ProductScanFailed] when AI can't read them now.
  Future<ProductDraft> scan(List<String> fileIds, {String? barcode});
}

/// [SuppliesRepository] over the generated API client.
class ApiSuppliesRepository implements SuppliesRepository {
  ApiSuppliesRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Supply>> getSupplies() async => [
    for (final supply in await _client.send(
      (api) => api.supplies.listSupplies(),
    ))
      supplyFromDto(supply),
  ];

  @override
  Future<Supply> getSupply(String id) async => supplyFromDto(
    await _client.send((api) => api.supplies.getSupply(id: id)),
  );

  @override
  Future<Supply> createSupply(
    SupplyInput input, {
    required String requestId,
  }) async => supplyFromDto(
    await _client.send(
      (api) => api.supplies.createSupply(
        body: _request(input, requestId: requestId),
      ),
    ),
  );

  @override
  Future<Supply> updateSupply(String id, SupplyInput input) async =>
      supplyFromDto(
        await _client.send(
          (api) => api.supplies.updateSupply(
            id: id,
            body: _request(input, requestId: null),
          ),
        ),
      );

  @override
  Future<void> deleteSupply(String id) =>
      _client.send((api) => api.supplies.deleteSupply(id: id));

  @override
  Future<List<StockEntry>> getStock(String supplyId) async => [
    for (final entry in await _client.send(
      (api) => api.supplies.listStockEvents(id: supplyId),
    ))
      _entryFromDto(entry),
  ];

  @override
  Future<Supply> addStock(
    String supplyId,
    StockEventKind kind,
    double quantity, {
    required String requestId,
  }) async {
    final change = await _client.send(
      (api) => api.supplies.addStockEvent(
        id: supplyId,
        body: dto.StockEventRequest(
          kind: switch (kind) {
            StockEventKind.purchase => dto.StockEventKind.purchase,
            StockEventKind.adjustment => dto.StockEventKind.adjustment,
          },
          quantity: quantity,
          requestId: requestId,
        ),
      ),
    );
    return supplyFromDto(change.supply);
  }

  @override
  Future<void> deleteStock(String supplyId, String entryId) => _client.send(
    (api) => api.supplies.deleteStockEvent(id: supplyId, eventId: entryId),
  );

  @override
  Future<ProductLookup> lookup(String code) async {
    final dto.ProductLookupResponse found;
    try {
      found = await _client.send(
        (api) => api.supplies.lookupProduct(code: code),
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.validation) throw const NotAProductCode();
      rethrow;
    }
    final existing = found.existing;
    final product = found.product;
    return ProductLookup(
      code: found.code,
      batch: found.batch,
      expiresOn: found.expiresOn,
      existing: existing == null
          ? null
          : ExistingSupply(
              id: existing.id,
              name: existing.name,
              active: existing.active,
            ),
      product: product == null
          ? null
          : ProductDetails(
              name: product.name,
              brand: product.brand,
              category: _categoryFromDto(product.category),
              unit: _unitFromDto(product.unit),
              packageSize: product.packageSize,
              kcalPerKg: product.kcalPerKg,
            ),
      source: switch (found.source) {
        dto.ProductLookupSource.catalog => ProductSource.catalog,
        dto.ProductLookupSource.openPetFoodFacts =>
          ProductSource.openPetFoodFacts,
        dto.ProductLookupSource.upcItemDb => ProductSource.upcItemDb,
        _ => null,
      },
    );
  }

  @override
  Future<ProductDraft> scan(List<String> fileIds, {String? barcode}) async {
    final dto.ProductScanResponse read;
    try {
      read = await _client.send(
        (api) => api.supplies.scanProduct(
          body: dto.ProductScanRequest(fileIds: fileIds, barcode: barcode),
        ),
      );
    } on ApiException catch (error) {
      // The month's AI photos are a 409 too, of their own type: the screen
      // says how many are left.
      if (error.problemType == ProblemTypes.aiLimit) rethrow;
      final problem = switch (error.statusCode) {
        409 => ProductScanProblem.notConfigured,
        502 => ProductScanProblem.rejected,
        503 => ProductScanProblem.busy,
        _ => null,
      };
      if (problem != null) throw ProductScanFailed(problem);
      rethrow;
    }
    final product = read.product;
    final unit = _unitFromDto(product.unit);
    return ProductDraft(
      isPetProduct: product.isPetProduct,
      name: product.name,
      brand: product.brand,
      category: _categoryFromDto(product.category),
      // A size in a unit this app doesn't know is no size.
      unit: unit,
      packageSize: unit == null ? null : product.packageSize,
      kcalPerKg: product.kcalPerKg,
      barcode: product.barcode,
      treatment: switch (product.treatment) {
        final kind? when kind != dto.CareKind.$unknown => careKindFromDto(kind),
        _ => null,
      },
      protectionWeeks: product.protectionWeeks,
      dosesInPackage: product.dosesInPackage,
      evidence: product.evidence,
    );
  }

  static dto.SupplyRequest _request(
    SupplyInput input, {
    required String? requestId,
  }) => dto.SupplyRequest(
    name: input.name,
    brand: input.brand,
    barcode: input.barcode,
    category: _categoryToDto(input.category),
    unit: _unitToDto(input.unit),
    packageSize: input.packageSize,
    kcalPerKg: input.kcalPerKg,
    usageMode: switch (input.usageMode) {
      SupplyUsageMode.feeding => dto.SupplyUsageMode.feeding,
      SupplyUsageMode.manual => dto.SupplyUsageMode.manual,
    },
    manualDailyUsage: input.manualDailyUsage,
    leadTimeDays: input.leadTimeDays,
    storeUrl: input.storeUrl,
    notes: input.notes,
    active: input.active,
    initialStock: input.initialStock,
    dataSource: switch (input.dataSource) {
      SupplyDataSource.manual => dto.SupplyDataSource.manual,
      SupplyDataSource.catalog => dto.SupplyDataSource.catalog,
      SupplyDataSource.openPetFoodFacts =>
        dto.SupplyDataSource.openPetFoodFacts,
      SupplyDataSource.upcItemDb => dto.SupplyDataSource.upcItemDb,
      SupplyDataSource.ai => dto.SupplyDataSource.ai,
      null => null,
    },
    requestId: requestId,
  );

  static StockEntry _entryFromDto(dto.StockEventResponse entry) => StockEntry(
    id: entry.id,
    kind: switch (entry.kind) {
      dto.StockEventKind.purchase => StockEventKind.purchase,
      dto.StockEventKind.adjustment => StockEventKind.adjustment,
      _ => null,
    },
    quantity: entry.quantity,
    at: entry.at.toLocal(),
    byName: entry.byName,
    byMe: entry.byMe,
  );
}

Supply supplyFromDto(dto.SupplyResponse supply) {
  final category = _categoryFromDto(supply.category);
  final unit = _unitFromDto(supply.unit);
  final usageMode = switch (supply.usageMode) {
    dto.SupplyUsageMode.feeding => SupplyUsageMode.feeding,
    dto.SupplyUsageMode.manual => SupplyUsageMode.manual,
    _ => null,
  };
  final forecast = supply.forecast;
  final status = supplyStatusFromDto(forecast.status);
  return Supply(
    id: supply.id,
    name: supply.name,
    brand: supply.brand,
    barcode: supply.barcode,
    category: category ?? SupplyCategory.other,
    unit: unit ?? SupplyUnit.piece,
    packageSize: supply.packageSize,
    kcalPerKg: supply.kcalPerKg,
    usageMode: usageMode ?? SupplyUsageMode.manual,
    manualDailyUsage: supply.manualDailyUsage,
    leadTimeDays: supply.leadTimeDays,
    storeUrl: supply.storeUrl,
    notes: supply.notes,
    active: supply.active,
    forecast: SupplyForecast(
      status: status ?? SupplyStatus.noUsage,
      remaining: forecast.remaining,
      usagePerDay: forecast.usagePerDay,
      daysLeft: forecast.daysLeft,
      runsOutOn: _date(forecast.runsOutOn),
      buyBy: _date(forecast.buyBy),
      countedFrom: forecast.countedFrom?.toLocal(),
    ),
    feedings: [
      for (final feeding in supply.feedings)
        SupplyFeeding(
          routineId: feeding.routineId,
          petId: feeding.petId,
          petName: feeding.petName,
          amount: feeding.amount,
          unit: portionUnitFromDto(feeding.unit),
          timesPerDay: feeding.timesPerDay,
          counted: feeding.counted,
        ),
    ],
    hasUnknownValues:
        category == null || unit == null || usageMode == null || status == null,
  );
}

SupplyStatus? supplyStatusFromDto(dto.SupplyStatus status) => switch (status) {
  dto.SupplyStatus.noStock => SupplyStatus.noStock,
  dto.SupplyStatus.noUsage => SupplyStatus.noUsage,
  dto.SupplyStatus.enough => SupplyStatus.enough,
  dto.SupplyStatus.soon => SupplyStatus.soon,
  dto.SupplyStatus.buyNow => SupplyStatus.buyNow,
  dto.SupplyStatus.outOfStock => SupplyStatus.outOfStock,
  dto.SupplyStatus.$unknown => null,
};

SupplyCategory? supplyCategoryFromDto(dto.SupplyCategory? category) =>
    _categoryFromDto(category);

SupplyUnit? supplyUnitFromDto(dto.SupplyUnit? unit) => _unitFromDto(unit);

SupplyCategory? _categoryFromDto(dto.SupplyCategory? category) =>
    switch (category) {
      dto.SupplyCategory.dryFood => SupplyCategory.dryFood,
      dto.SupplyCategory.wetFood => SupplyCategory.wetFood,
      dto.SupplyCategory.treats => SupplyCategory.treats,
      dto.SupplyCategory.litter => SupplyCategory.litter,
      dto.SupplyCategory.medication => SupplyCategory.medication,
      dto.SupplyCategory.other => SupplyCategory.other,
      _ => null,
    };

dto.SupplyCategory _categoryToDto(SupplyCategory category) =>
    switch (category) {
      SupplyCategory.dryFood => dto.SupplyCategory.dryFood,
      SupplyCategory.wetFood => dto.SupplyCategory.wetFood,
      SupplyCategory.treats => dto.SupplyCategory.treats,
      SupplyCategory.litter => dto.SupplyCategory.litter,
      SupplyCategory.medication => dto.SupplyCategory.medication,
      SupplyCategory.other => dto.SupplyCategory.other,
    };

SupplyUnit? _unitFromDto(dto.SupplyUnit? unit) => switch (unit) {
  dto.SupplyUnit.gram => SupplyUnit.gram,
  dto.SupplyUnit.milliliter => SupplyUnit.milliliter,
  dto.SupplyUnit.piece => SupplyUnit.piece,
  dto.SupplyUnit.dose => SupplyUnit.dose,
  _ => null,
};

dto.SupplyUnit _unitToDto(SupplyUnit unit) => switch (unit) {
  SupplyUnit.gram => dto.SupplyUnit.gram,
  SupplyUnit.milliliter => dto.SupplyUnit.milliliter,
  SupplyUnit.piece => dto.SupplyUnit.piece,
  SupplyUnit.dose => dto.SupplyUnit.dose,
};

DateTime? _date(DateTime? date) =>
    date == null ? null : DateTime(date.year, date.month, date.day);

// --- Providers --------------------------------------------------------------

final suppliesRepositoryProvider = Provider<SuppliesRepository>(
  (ref) => ApiSuppliesRepository(ref.watch(apiClientProvider)),
);

/// All supplies of the household, for the Supplies tab.
final suppliesProvider = FutureProvider.autoDispose<List<Supply>>((ref) async {
  final repository = ref.watch(suppliesRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getSupplies();
});

/// One item, for its page and form.
final supplyProvider = FutureProvider.autoDispose.family<Supply, String>((
  ref,
  id,
) async {
  final repository = ref.watch(suppliesRepositoryProvider);
  await ref.watch(profileSyncProvider.future);
  return repository.getSupply(id);
});

/// An item's purchases and counts, newest first.
final stockProvider = FutureProvider.autoDispose
    .family<List<StockEntry>, String>((ref, id) async {
      final repository = ref.watch(suppliesRepositoryProvider);
      await ref.watch(profileSyncProvider.future);
      return repository.getStock(id);
    });
