import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/l10n.dart';
import 'document.dart';

String documentTypeLabel(AppLocalizations l10n, DocumentType type) =>
    switch (type) {
      DocumentType.passportPage => l10n.documentTypePassportPage,
      DocumentType.vaccinationCertificate =>
        l10n.documentTypeVaccinationCertificate,
      DocumentType.labResult => l10n.documentTypeLabResult,
      DocumentType.prescription => l10n.documentTypePrescription,
      DocumentType.invoice => l10n.documentTypeInvoice,
      DocumentType.insurance => l10n.documentTypeInsurance,
      DocumentType.other => l10n.documentTypeOther,
    };

IconData documentTypeIcon(DocumentType type) => switch (type) {
  DocumentType.passportPage => Symbols.menu_book_rounded,
  DocumentType.vaccinationCertificate => Symbols.vaccines_rounded,
  DocumentType.labResult => Symbols.science_rounded,
  DocumentType.prescription => Symbols.medication_rounded,
  DocumentType.invoice => Symbols.receipt_long_rounded,
  DocumentType.insurance => Symbols.shield_rounded,
  DocumentType.other => Symbols.description_rounded,
};

/// The document's title, or its type when it has none.
String documentTitle(AppLocalizations l10n, PetDocument document) {
  final title = document.title?.trim();
  return title == null || title.isEmpty
      ? documentTypeLabel(l10n, document.type)
      : title;
}
