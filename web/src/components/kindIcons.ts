// The icons of kinds of care, visits, supplies, documents and weights: the phone app's choices (care_labels.dart,
// visit_labels.dart, supply_labels.dart, document_labels.dart, weight_labels.dart) in Material Symbols.
import type { CareKind, DocumentType, SupplyCategory, VisitType, WeightSource } from '../api/types';
import type { IconName } from './icons';

export const CARE_KIND_ICONS: Record<CareKind, IconName> = {
  Vaccination: 'vaccines',
  RabiesTiter: 'bloodtype',
  Deworming: 'medication',
  Echinococcus: 'flight_takeoff',
  FleaTick: 'pest_control',
  Heartworm: 'monitor_heart',
  VetExam: 'medical_services',
  Dental: 'sentiment_satisfied',
  Grooming: 'content_cut',
  Procedure: 'healing',
  Other: 'event_note',
};

export const VISIT_TYPE_ICONS: Record<VisitType, IconName> = {
  Vet: 'local_hospital',
  Grooming: 'content_cut',
  Training: 'sports',
  Other: 'event',
};

/** The status tag of an item to buy (lib/labels.ts supplyStatusTone): ran out, or time to buy. */
export const SUPPLY_STATUS_ICONS: Record<'danger' | 'warning', IconName> = {
  danger: 'remove_shopping_cart',
  warning: 'add_shopping_cart',
};

export const SUPPLY_ICONS: Record<SupplyCategory, IconName> = {
  DryFood: 'rice_bowl',
  WetFood: 'soup_kitchen',
  Treats: 'cookie',
  Litter: 'layers',
  Medication: 'medication',
  Other: 'inventory_2',
};

export const DOCUMENT_TYPE_ICONS: Record<DocumentType, IconName> = {
  PassportPage: 'menu_book',
  VaccinationCertificate: 'vaccines',
  LabResult: 'science',
  Prescription: 'medication',
  Invoice: 'receipt_long',
  Insurance: 'shield',
  Other: 'description',
};

/** A scale for a weighing, the check-up's icon for a vet's weight. */
export const WEIGHT_SOURCE_ICONS: Record<WeightSource, IconName> = {
  Weighing: 'monitor_weight',
  CareRecord: 'medical_services',
};
