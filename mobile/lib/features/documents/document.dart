import 'package:flutter/foundation.dart';

import '../files/stored_file.dart';

enum DocumentType {
  /// Photos of the paper passport's pages (the Passport tab's "Pages").
  passportPage,
  vaccinationCertificate,
  labResult,
  prescription,
  invoice,
  insurance,
  other,
}

/// A document of a pet: one or more pages, each a photo or a PDF.
@immutable
class PetDocument {
  const PetDocument({
    required this.id,
    required this.type,
    required this.pages,
    required this.createdAt,
    this.petId,
    this.title,
    this.documentDate,
    this.notes,
  });

  final String id;
  final String? petId;
  final DocumentType type;
  final String? title;

  /// The date on the document, if the user entered one.
  final DateTime? documentDate;
  final String? notes;

  /// In page order.
  final List<StoredFile> pages;
  final DateTime createdAt;

  static const maxPages = 50;

  @override
  bool operator ==(Object other) =>
      other is PetDocument &&
      other.id == id &&
      other.petId == petId &&
      other.type == type &&
      other.title == title &&
      other.documentDate == documentDate &&
      other.notes == notes &&
      listEquals(other.pages, pages) &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    petId,
    type,
    title,
    documentDate,
    notes,
    Object.hashAll(pages),
    createdAt,
  );

  @override
  String toString() => 'PetDocument($id, ${type.name}, ${pages.length} pages)';
}

/// A document's type, title, date and notes: what editing a document
/// changes. Pages are added and removed one by one, never replaced as a
/// list, so pages added elsewhere in the meantime are never lost.
@immutable
class DocumentDetails {
  const DocumentDetails({
    required this.type,
    this.title,
    this.documentDate,
    this.notes,
  });

  final DocumentType type;
  final String? title;
  final DateTime? documentDate;
  final String? notes;

  @override
  bool operator ==(Object other) =>
      other is DocumentDetails &&
      other.type == type &&
      other.title == title &&
      other.documentDate == documentDate &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(type, title, documentDate, notes);

  @override
  String toString() => 'DocumentDetails(${type.name}, $title)';
}
