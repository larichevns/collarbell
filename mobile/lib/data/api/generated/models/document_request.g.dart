// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DocumentRequest _$DocumentRequestFromJson(Map<String, dynamic> json) =>
    DocumentRequest(
      type: DocumentType.fromJson(json['type']),
      title: json['title'] as String?,
      documentDate: const DateOnlyConverter().fromJson(
        json['documentDate'] as String?,
      ),
      notes: json['notes'] as String?,
      fileIds: (json['fileIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$DocumentRequestToJson(DocumentRequest instance) =>
    <String, dynamic>{
      'type': _$DocumentTypeEnumMap[instance.type]!,
      'title': instance.title,
      'documentDate': const DateOnlyConverter().toJson(instance.documentDate),
      'notes': instance.notes,
      'fileIds': instance.fileIds,
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
