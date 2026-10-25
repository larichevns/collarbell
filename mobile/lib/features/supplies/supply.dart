import 'package:flutter/foundation.dart';

import '../care/care.dart';
import '../feeding/feeding.dart';

enum SupplyCategory { dryFood, wetFood, treats, litter, medication, other }

/// What the package size and the stock are counted in.
enum SupplyUnit { gram, milliliter, piece, dose }

/// Where the daily use comes from: the portions of the feeding schedules
/// that give this food, or a use the user sets.
enum SupplyUsageMode { feeding, manual }

/// How an item's stock looks, most urgent last.
enum SupplyStatus { noStock, noUsage, enough, soon, buyNow, outOfStock }

enum StockEventKind { purchase, adjustment }

/// Where a barcode lookup found the product.
enum ProductSource { catalog, openPetFoodFacts, upcItemDb }

/// Where the details of a new item came from; the server keeps products
/// users confirm in its catalog, except those of Open Pet Food Facts.
enum SupplyDataSource { manual, catalog, openPetFoodFacts, upcItemDb, ai }

/// Food is counted in the categories that can be given at feeding time.
bool isFood(SupplyCategory category) => switch (category) {
  SupplyCategory.dryFood ||
  SupplyCategory.wetFood ||
  SupplyCategory.treats => true,
  _ => false,
};

/// The unit of a portion that counts towards an item in [unit], or null
/// when no portion can (doses).
PortionUnit? portionUnitFor(SupplyUnit unit) => switch (unit) {
  SupplyUnit.gram => PortionUnit.gram,
  SupplyUnit.milliliter => PortionUnit.milliliter,
  SupplyUnit.piece => PortionUnit.piece,
  SupplyUnit.dose => null,
};

/// The server's estimate (spec 5.3). Amounts are in the item's unit; the
/// dates are the household's.
@immutable
class SupplyForecast {
  const SupplyForecast({
    required this.status,
    this.remaining,
    this.usagePerDay,
    this.daysLeft,
    this.runsOutOn,
    this.buyBy,
    this.countedFrom,
  });

  final SupplyStatus status;

  /// What is left now; null before the first purchase or count.
  final double? remaining;
  final double? usagePerDay;
  final double? daysLeft;
  final DateTime? runsOutOn;

  /// The day to buy it: the delivery time before it runs out.
  final DateTime? buyBy;

  /// The purchase or count the estimate starts from.
  final DateTime? countedFrom;
}

/// A feeding schedule that gives this food. [counted] is false when its
/// portion can't count (no amount, or another unit).
@immutable
class SupplyFeeding {
  const SupplyFeeding({
    required this.routineId,
    required this.petId,
    required this.petName,
    required this.timesPerDay,
    required this.counted,
    this.amount,
    this.unit,
  });

  final String routineId;
  final String petId;
  final String petName;
  final double? amount;
  final PortionUnit? unit;

  /// On average: twice a day on weekends only is 4/7.
  final double timesPerDay;
  final bool counted;
}

/// A food, litter or medication in stock, with the server's estimate.
@immutable
class Supply {
  const Supply({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.packageSize,
    required this.usageMode,
    required this.leadTimeDays,
    required this.forecast,
    this.brand,
    this.barcode,
    this.kcalPerKg,
    this.manualDailyUsage,
    this.storeUrl,
    this.notes,
    this.active = true,
    this.feedings = const [],
    this.hasUnknownValues = false,
  });

  final String id;
  final String name;
  final String? brand;
  final String? barcode;
  final SupplyCategory category;
  final SupplyUnit unit;

  /// How much one package holds, in [unit].
  final double packageSize;
  final int? kcalPerKg;
  final SupplyUsageMode usageMode;
  final double? manualDailyUsage;

  /// Days an order takes to arrive: the reminder comes this much earlier.
  final int leadTimeDays;
  final String? storeUrl;
  final String? notes;

  /// False for an item no longer bought: no estimate reminders.
  final bool active;
  final SupplyForecast forecast;
  final List<SupplyFeeding> feedings;

  /// Values from a newer server this app doesn't know: it isn't edited,
  /// because saving would replace them.
  final bool hasUnknownValues;

  /// To buy now: it has run out, or runs out within the delivery time.
  bool get needsBuying =>
      active &&
      (forecast.status == SupplyStatus.buyNow ||
          forecast.status == SupplyStatus.outOfStock);
}

/// What the supply form saves.
@immutable
class SupplyInput {
  const SupplyInput({
    required this.name,
    required this.category,
    required this.unit,
    required this.packageSize,
    required this.usageMode,
    required this.leadTimeDays,
    this.brand,
    this.barcode,
    this.kcalPerKg,
    this.manualDailyUsage,
    this.storeUrl,
    this.notes,
    this.active,
    this.initialStock,
    this.dataSource,
  });

  final String name;
  final String? brand;
  final String? barcode;
  final SupplyCategory category;
  final SupplyUnit unit;
  final double packageSize;
  final int? kcalPerKg;
  final SupplyUsageMode usageMode;
  final double? manualDailyUsage;
  final int leadTimeDays;
  final String? storeUrl;
  final String? notes;

  /// Null keeps it as it is (new items are bought).
  final bool? active;

  /// Adding only: what is there now, in [unit]; null when unknown.
  final double? initialStock;
  final SupplyDataSource? dataSource;
}

/// A purchase or a count of what was left, and who entered it.
@immutable
class StockEntry {
  const StockEntry({
    required this.id,
    required this.kind,
    required this.quantity,
    required this.at,
    required this.byMe,
    this.byName,
  });

  final String id;

  /// Null for a kind this app doesn't know.
  final StockEventKind? kind;
  final double quantity;

  /// Local time.
  final DateTime at;
  final String? byName;
  final bool byMe;
}

/// What a product database knows about a product; only the name is sure.
@immutable
class ProductDetails {
  const ProductDetails({
    required this.name,
    this.brand,
    this.category,
    this.unit,
    this.packageSize,
    this.kcalPerKg,
  });

  final String name;
  final String? brand;
  final SupplyCategory? category;
  final SupplyUnit? unit;
  final double? packageSize;
  final int? kcalPerKg;
}

/// The household's item with a scanned barcode.
@immutable
class ExistingSupply {
  const ExistingSupply({
    required this.id,
    required this.name,
    required this.active,
  });

  final String id;
  final String name;
  final bool active;
}

/// What a scanned code is: the product's barcode, and for a medicine's
/// DataMatrix also its batch and expiry date.
@immutable
class ProductLookup {
  const ProductLookup({
    required this.code,
    this.batch,
    this.expiresOn,
    this.existing,
    this.product,
    this.source,
  });

  final String code;
  final String? batch;
  final DateTime? expiresOn;

  /// Already in supplies.
  final ExistingSupply? existing;
  final ProductDetails? product;
  final ProductSource? source;
}

/// Photos of a package as AI read them, checked by the server. For a
/// medicine, [treatment] and [protectionWeeks] can start a treatment plan.
@immutable
class ProductDraft {
  const ProductDraft({
    required this.isPetProduct,
    this.name,
    this.brand,
    this.category,
    this.unit,
    this.packageSize,
    this.kcalPerKg,
    this.barcode,
    this.treatment,
    this.protectionWeeks,
    this.dosesInPackage,
    this.evidence,
  });

  final bool isPetProduct;
  final String? name;
  final String? brand;
  final SupplyCategory? category;
  final SupplyUnit? unit;
  final double? packageSize;
  final int? kcalPerKg;
  final String? barcode;
  final CareKind? treatment;
  final int? protectionWeeks;
  final int? dosesInPackage;

  /// The main text read on the package.
  final String? evidence;
}

/// What a new item's form starts with: from a barcode lookup, photos of the
/// package, or both.
@immutable
class SupplyPrefill {
  const SupplyPrefill({
    this.barcode,
    this.name,
    this.brand,
    this.category,
    this.unit,
    this.packageSize,
    this.kcalPerKg,
    this.dataSource = SupplyDataSource.manual,
    this.readFromPhotos = false,
    this.treatment,
    this.protectionWeeks,
    this.notPetProduct = false,
    this.batch,
    this.expiresOn,
  });

  /// [lookup]'s product, then what [draft] read where the product says
  /// nothing: a database's name is spelled as on the shelf, the photos
  /// often know the size.
  factory SupplyPrefill.from({
    ProductLookup? lookup,
    ProductDraft? draft,
    String? code,
  }) {
    final product = lookup?.product;
    return SupplyPrefill(
      barcode: lookup?.code ?? code ?? draft?.barcode,
      name: product?.name ?? draft?.name,
      brand: product?.brand ?? draft?.brand,
      category: product?.category ?? draft?.category,
      unit: product?.packageSize != null ? product?.unit : draft?.unit,
      packageSize: product?.packageSize ?? draft?.packageSize,
      kcalPerKg: product?.kcalPerKg ?? draft?.kcalPerKg,
      // Details of Open Pet Food Facts stay theirs when photos fill in the
      // rest: shown with their licence, and never copied to our catalog.
      dataSource: switch (lookup?.source) {
        ProductSource.openPetFoodFacts when product != null =>
          SupplyDataSource.openPetFoodFacts,
        _ when draft != null => SupplyDataSource.ai,
        ProductSource.catalog => SupplyDataSource.catalog,
        ProductSource.upcItemDb => SupplyDataSource.upcItemDb,
        _ => SupplyDataSource.manual,
      },
      readFromPhotos: draft != null,
      treatment: draft?.treatment,
      protectionWeeks: draft?.protectionWeeks,
      notPetProduct: draft != null && !draft.isPetProduct,
      batch: lookup?.batch,
      expiresOn: lookup?.expiresOn,
    );
  }

  final String? barcode;
  final String? name;
  final String? brand;
  final SupplyCategory? category;
  final SupplyUnit? unit;
  final double? packageSize;
  final int? kcalPerKg;
  final SupplyDataSource dataSource;

  /// Some details were read from photos of the package.
  final bool readFromPhotos;
  final CareKind? treatment;
  final int? protectionWeeks;

  /// AI thinks the photos don't show a pet product.
  final bool notPetProduct;

  /// A medicine's batch and expiry date, from its DataMatrix.
  final String? batch;
  final DateTime? expiresOn;
}

/// A supply to buy now, on the Today screen.
@immutable
class TodaySupply {
  const TodaySupply({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.packageSize,
    required this.status,
    this.brand,
    this.remaining,
    this.daysLeft,
    this.runsOutOn,
  });

  final String id;
  final String name;
  final String? brand;
  final SupplyCategory category;
  final SupplyUnit unit;
  final double packageSize;
  final SupplyStatus status;
  final double? remaining;
  final double? daysLeft;
  final DateTime? runsOutOn;
}
