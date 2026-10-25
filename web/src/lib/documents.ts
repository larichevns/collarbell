// A pet's documents and the passport's pages (the phone app's document.dart and passport_pages.dart). The photographed
// pages of the paper passport are the pages of the pet's PassportPage documents: usually one, though the Documents tab
// can make more. Pages are added and removed one by one, never sent as a list, so pages added elsewhere meanwhile are
// never lost.
import type { DocumentType, FileLink, PetDocument } from '../api/types';
import type { Messages } from '../i18n/en';

/** The server's limits. */
export const DOCUMENT_MAX = { pages: 50, title: 200, notes: 2000 } as const;

/** Every type, in the order the app lists them. */
export const DOCUMENT_TYPES: readonly DocumentType[] = [
  'PassportPage',
  'VaccinationCertificate',
  'LabResult',
  'Prescription',
  'Invoice',
  'Insurance',
  'Other',
];

/** The document's title, or its type when it has none. */
export function documentTitle(t: Messages, document: Pick<PetDocument, 'title' | 'type'>): string {
  return document.title?.trim() || t.documentType[document.type];
}

/** The documents by type, in the app's order of types; each keeps the server's order (newest first). */
export function documentsByType(documents: readonly PetDocument[]): [DocumentType, PetDocument[]][] {
  return DOCUMENT_TYPES.map((type): [DocumentType, PetDocument[]] => [
    type,
    documents.filter((document) => document.type === type),
  ]).filter(([, group]) => group.length > 0);
}

/** The pet's passport-page documents, oldest first (the list comes newest first): added pages go to the end. */
export function passportPageDocuments(documents: readonly PetDocument[]): PetDocument[] {
  return [...documents].reverse().filter((document) => document.type === 'PassportPage');
}

/** Every passport page, in the order the grid shows them, with the document each belongs to. */
export function passportPages(documents: readonly PetDocument[]): { page: FileLink; documentId: string }[] {
  return passportPageDocuments(documents).flatMap((document) =>
    document.pages.map((page) => ({ page, documentId: document.id })),
  );
}
