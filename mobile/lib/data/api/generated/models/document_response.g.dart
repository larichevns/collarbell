// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DocumentResponse _$DocumentResponseFromJson(Map<String, dynamic> json) =>
    DocumentResponse(
      id: json['id'] as String,
      petId: json['petId'] as String?,
      type: DocumentType.fromJson(json['type']),
      title: json['title'] as String?,
      documentDate: const DateOnlyConverter().fromJson(
        json['documentDate'] as String?,
      ),
      notes: json['notes'] as String?,
      pages: (json['pages'] as List<dynamic>)
          .map((e) => FileLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: const RequiredDateOnlyConverter().fromJson(
        json['createdAt'] as String,
      ),
      updatedAt: const RequiredDateOnlyConverter().fromJson(
        json['updatedAt'] as String,
      ),
    );

Map<String, dynamic> _$DocumentResponseToJson(DocumentResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'petId': instance.petId,
      'type': _$DocumentTypeEnumMap[instance.type]!,
      'title': instance.title,
      'documentDate': const DateOnlyConverter().toJson(instance.documentDate),
      'notes': instance.notes,
      'pages': instance.pages.map((e) => e.toJson()).toList(),
      'createdAt': const RequiredDateOnlyConverter().toJson(instance.createdAt),
      'updatedAt': const RequiredDateOnlyConverter().toJson(instance.updatedAt),
    };

const _$DocumentTypeEnumMap = {
  DocumentType.passportPage: 'PassportPage',
  DocumentType.vaccinationCertificate: 'VaccinationCertificate',
  DocumentType.labResult: 'LabResult',
  DocumentType.prescription: 'Prescription',
  DocumentType.invoice: 'Invoice',
  DocumentType.insurance: 'Insurance',
  DocumentType.other: 'Other',
  DocumentType.$unknown: r'$unknown',
};
