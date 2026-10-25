// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_scan_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductScanRequest _$ProductScanRequestFromJson(Map<String, dynamic> json) =>
    ProductScanRequest(
      fileIds: (json['fileIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      barcode: json['barcode'] as String?,
    );

Map<String, dynamic> _$ProductScanRequestToJson(ProductScanRequest instance) =>
    <String, dynamic>{'fileIds': instance.fileIds, 'barcode': instance.barcode};
