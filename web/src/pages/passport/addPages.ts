// Adding photographed pages to the passport (the phone app's passport_pages.dart): they go to the end of the newest
// PassportPage document, or start one when the pet has none; a document takes 50 pages, so more start another. The
// pet's documents are asked for first instead of trusting the list on screen, which can be old; pages already there
// are skipped, so a retry after a lost answer adds nothing twice.
import { data, type ApiClient } from '../../api/client';
import type { FileLink } from '../../api/types';
import { DOCUMENT_MAX, passportPageDocuments } from '../../lib/documents';

export async function addPassportPages(api: ApiClient, petId: string, uploaded: readonly FileLink[]): Promise<void> {
  const documents = passportPageDocuments(
    await data(api.GET('/api/v1/pets/{petId}/documents', { params: { path: { petId } } })),
  );
  const there = new Set(documents.flatMap((document) => document.pages.map((page) => page.id)));
  let fileIds = uploaded.map((link) => link.id).filter((id) => !there.has(id));
  const last = documents.at(-1);
  const room = last ? DOCUMENT_MAX.pages - last.pages.length : 0;
  if (last && room > 0 && fileIds.length) {
    await api.POST('/api/v1/documents/{id}/pages', {
      params: { path: { id: last.id } },
      body: { fileIds: fileIds.slice(0, room) },
    });
    fileIds = fileIds.slice(room);
  }
  while (fileIds.length) {
    await api.POST('/api/v1/pets/{petId}/documents', {
      params: { path: { petId } },
      body: {
        type: 'PassportPage',
        title: null,
        documentDate: null,
        notes: null,
        fileIds: fileIds.slice(0, DOCUMENT_MAX.pages),
      },
    });
    fileIds = fileIds.slice(DOCUMENT_MAX.pages);
  }
}
