// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_lookup_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductLookupResponse _$ProductLookupResponseFromJson(
  Map<String, dynamic> json,
) => ProductLookupResponse(
  code: json['code'] as String,
  batch: json['batch'] as String?,
  expiresOn: const DateOnlyConverter().fromJson(json['expiresOn'] as String?),
  existing: json['existing'] == null
      ? null
      : ExistingSupply.fromJson(json['existing'] as Map<String, dynamic>),
  product: json['product'] == null
      ? null
      : ProductDetails.fromJson(json['product'] as Map<String, dynamic>),
  source: json['source'] == null
      ? null
      : ProductLookupSource.fromJson(json['source']),
);

Map<String, dynamic> _$ProductLookupResponseToJson(
  ProductLookupResponse instance,
) => <String, dynamic>{
  'code': instance.code,
  'batch': instance.batch,
  'expiresOn': const DateOnlyConverter().toJson(instance.expiresOn),
  'existing': instance.existing?.toJson(),
  'product': instance.product?.toJson(),
  'source': _$ProductLookupSourceEnumMap[instance.source],
};

const _$ProductLookupSourceEnumMap = {
  ProductLookupSource.catalog: 'Catalog',
  ProductLookupSource.openPetFoodFacts: 'OpenPetFoodFacts',
  ProductLookupSource.upcItemDb: 'UpcItemDb',
  ProductLookupSource.valueNull: null,
  ProductLookupSource.$unknown: r'$unknown',
};
