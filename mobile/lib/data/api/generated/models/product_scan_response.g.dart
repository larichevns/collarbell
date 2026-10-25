// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_scan_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductScanResponse _$ProductScanResponseFromJson(Map<String, dynamic> json) =>
    ProductScanResponse(
      product: ProductDraft.fromJson(json['product'] as Map<String, dynamic>),
      model: json['model'] as String,
    );

Map<String, dynamic> _$ProductScanResponseToJson(
  ProductScanResponse instance,
) => <String, dynamic>{
  'product': instance.product.toJson(),
  'model': instance.model,
};
