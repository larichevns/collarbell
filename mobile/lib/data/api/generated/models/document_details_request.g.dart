// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_details_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DocumentDetailsRequest _$DocumentDetailsRequestFromJson(
  Map<String, dynamic> json,
) => DocumentDetailsRequest(
  type: DocumentType.fromJson(json['type']),
  title: json['title'] as String?,
  documentDate: const DateOnlyConverter().fromJson(
    json['documentDate'] as String?,
  ),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$DocumentDetailsRequestToJson(
  DocumentDetailsRequest instance,
) => <String, dynamic>{
  'type': _$DocumentTypeEnumMap[instance.type]!,
  'title': instance.title,
  'documentDate': const DateOnlyConverter().toJson(instance.documentDate),
  'notes': instance.notes,
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
