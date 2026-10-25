// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/product_lookup_response.dart';
import '../models/product_scan_request.dart';
import '../models/product_scan_response.dart';
import '../models/stock_change_response.dart';
import '../models/stock_event_request.dart';
import '../models/stock_event_response.dart';
import '../models/supply_request.dart';
import '../models/supply_response.dart';

part 'supplies_client.g.dart';

@RestApi()
abstract class SuppliesClient {
  factory SuppliesClient(Dio dio, {String? baseUrl}) = _SuppliesClient;

  /// What a scanned barcode is: the household's item with it, or the product from the catalog, Open Pet Food Facts or UPCitemdb.
  @GET('/api/v1/products/lookup')
  Future<ProductLookupResponse> lookupProduct({
    @Query('code') String? code,
  });

  /// Read photos of a package with AI: name, brand, size, energy, and for a medicine how long a dose protects. Waits for the answer (up to a few minutes). 409 urn:collarbell:problem:ai-limit: not enough AI photos left this month; 409 without a type: AI isn't set up; 429: too many AI requests in a minute; 503: all models are busy.
  @POST('/api/v1/products/scan')
  Future<ProductScanResponse> scanProduct({
    @Body() required ProductScanRequest body,
  });

  /// The household's supplies with their estimates: what runs out first comes first, items no longer bought last.
  @GET('/api/v1/supplies')
  Future<List<SupplyResponse>> listSupplies();

  /// Add a food, litter or medication to supplies, with what is there now.
  @POST('/api/v1/supplies')
  Future<SupplyResponse> createSupply({
    @Body() required SupplyRequest body,
  });

  /// One supply item with its estimate and the feedings that use it.
  @GET('/api/v1/supplies/{id}')
  Future<SupplyResponse> getSupply({
    @Path('id') required String id,
  });

  /// Change a supply item; the stock stays as entered.
  @PUT('/api/v1/supplies/{id}')
  Future<SupplyResponse> updateSupply({
    @Path('id') required String id,
    @Body() required SupplyRequest body,
  });

  /// Delete a supply item and its purchases; feedings keep the food's name.
  @DELETE('/api/v1/supplies/{id}')
  Future<void> deleteSupply({
    @Path('id') required String id,
  });

  /// The item's purchases and counts, newest first (the last 50).
  @GET('/api/v1/supplies/{id}/stock-events')
  Future<List<StockEventResponse>> listStockEvents({
    @Path('id') required String id,
  });

  /// "Bought two bags" or "about half a bag left"; answers with the new estimate. A purchase of an item no longer bought makes it bought again.
  @POST('/api/v1/supplies/{id}/stock-events')
  Future<StockChangeResponse> addStockEvent({
    @Path('id') required String id,
    @Body() required StockEventRequest body,
  });

  /// Take back a purchase or a count entered by mistake.
  @DELETE('/api/v1/supplies/{id}/stock-events/{eventId}')
  Future<void> deleteStockEvent({
    @Path('id') required String id,
    @Path('eventId') required String eventId,
  });
}
