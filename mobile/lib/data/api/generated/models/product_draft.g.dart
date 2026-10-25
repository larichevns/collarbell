// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_draft.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductDraft _$ProductDraftFromJson(Map<String, dynamic> json) => ProductDraft(
  isPetProduct: json['isPetProduct'] as bool,
  name: json['name'] as String?,
  brand: json['brand'] as String?,
  category: json['category'] == null
      ? null
      : SupplyCategory.fromJson(json['category']),
  unit: json['unit'] == null ? null : SupplyUnit.fromJson(json['unit']),
  packageSize: (json['packageSize'] as num?)?.toDouble(),
  kcalPerKg: (json['kcalPerKg'] as num?)?.toInt(),
  barcode: json['barcode'] as String?,
  species: json['species'] == null
      ? null
      : ProductSpecies.fromJson(json['species']),
  treatment: json['treatment'] == null
      ? null
      : CareKind.fromJson(json['treatment']),
  protectionWeeks: (json['protectionWeeks'] as num?)?.toInt(),
  dosesInPackage: (json['dosesInPackage'] as num?)?.toInt(),
  evidence: json['evidence'] as String?,
);

Map<String, dynamic> _$ProductDraftToJson(ProductDraft instance) =>
    <String, dynamic>{
      'isPetProduct': instance.isPetProduct,
      'name': instance.name,
      'brand': instance.brand,
      'category': _$SupplyCategoryEnumMap[instance.category],
      'unit': _$SupplyUnitEnumMap[instance.unit],
      'packageSize': instance.packageSize,
      'kcalPerKg': instance.kcalPerKg,
      'barcode': instance.barcode,
      'species': _$ProductSpeciesEnumMap[instance.species],
      'treatment': _$CareKindEnumMap[instance.treatment],
      'protectionWeeks': instance.protectionWeeks,
      'dosesInPackage': instance.dosesInPackage,
      'evidence': instance.evidence,
    };

const _$SupplyCategoryEnumMap = {
  SupplyCategory.dryFood: 'DryFood',
  SupplyCategory.wetFood: 'WetFood',
  SupplyCategory.treats: 'Treats',
  SupplyCategory.litter: 'Litter',
  SupplyCategory.medication: 'Medication',
  SupplyCategory.other: 'Other',
  SupplyCategory.$unknown: r'$unknown',
};

const _$SupplyUnitEnumMap = {
  SupplyUnit.gram: 'Gram',
  SupplyUnit.milliliter: 'Milliliter',
  SupplyUnit.piece: 'Piece',
  SupplyUnit.dose: 'Dose',
  SupplyUnit.$unknown: r'$unknown',
};

const _$ProductSpeciesEnumMap = {
  ProductSpecies.cat: 'Cat',
  ProductSpecies.dog: 'Dog',
  ProductSpecies.catAndDog: 'CatAndDog',
  ProductSpecies.other: 'Other',
  ProductSpecies.valueNull: null,
  ProductSpecies.$unknown: r'$unknown',
};

const _$CareKindEnumMap = {
  CareKind.vaccination: 'Vaccination',
  CareKind.rabiesTiter: 'RabiesTiter',
  CareKind.deworming: 'Deworming',
  CareKind.echinococcus: 'Echinococcus',
  CareKind.fleaTick: 'FleaTick',
  CareKind.heartworm: 'Heartworm',
  CareKind.vetExam: 'VetExam',
  CareKind.dental: 'Dental',
  CareKind.grooming: 'Grooming',
  CareKind.procedure: 'Procedure',
  CareKind.other: 'Other',
  CareKind.$unknown: r'$unknown',
};
