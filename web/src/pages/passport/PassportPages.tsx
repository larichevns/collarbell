// The photographed pages of the paper passport: a grid, as many as there are, in order. Those who change things drop
// photos or scans onto it (several at once) or pick them; they upload one after another and join the passport's
// pages (passportPages.ts). A page opens large, with the next and previous ones; a PDF opens in a new tab. A page is
// deleted after a question, from the grid or the large view.
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { errorMessage, isNotFound } from '../../api/errors';
import { isPdf } from '../../api/files';
import { keys } from '../../api/keys';
import { useDocuments } from '../../api/queries';
import type { FileLink, Pet } from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import { FileDrop, FileTile, UploadStatus } from '../../components/Files';
import { PageViewer } from '../../components/PageViewer';
import { useKeepFocus } from '../../components/useKeepFocus';
import { useUpload } from '../../components/useUpload';
import { Loaded, Notice, Section } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { passportPages } from '../../lib/documents';
import { addPassportPages } from './addPages';

export function PassportPages({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const api = useApi();
  const { current, permissions } = useHousehold();
  const queryClient = useQueryClient();
  const documents = useDocuments(pet.id);
  const [viewing, setViewing] = useState<string | null>(null);
  const [removing, setRemoving] = useState<{ page: FileLink; documentId: string } | null>(null);
  const [removeBusy, setRemoveBusy] = useState(false);
  const [removeError, setRemoveError] = useState<unknown>(null);
  // A page removed: the focus goes to the one now in its place.
  const container = useRef<HTMLDivElement>(null);
  useKeepFocus(container);

  const refresh = () => queryClient.invalidateQueries({ queryKey: keys.documents(current.id, pet.id) });
  const upload = useUpload(api, async (links) => {
    try {
      await addPassportPages(api, pet.id, links);
    } finally {
      // The grid, and the Documents tab, show what got through.
      void refresh();
    }
  });

  async function remove(page: FileLink, documentId: string) {
    try {
      await api.DELETE('/api/v1/documents/{id}/pages/{fileId}', {
        params: { path: { id: documentId, fileId: page.id } },
      });
    } catch (error) {
      // Gone already: that is what was wanted.
      if (!isNotFound(error)) throw error;
    } finally {
      void refresh();
    }
  }

  return (
    <Section title={t.passportPagesTitle}>
      <div ref={container}>
        <Loaded query={documents}>
          {(list) => {
            const pages = passportPages(list);
            const owner = new Map(pages.map(({ page, documentId }) => [page.id, documentId]));
            const grid = pages.length ? (
              <ul className="file-grid">
                {pages.map(({ page, documentId }, index) => (
                  <FileTile
                    key={page.id}
                    file={page}
                    label={t.passportPageLabel(index + 1)}
                    onOpen={() => setViewing(page.id)}
                    onRemove={permissions.canEdit ? () => setRemoving({ page, documentId }) : undefined}
                    removeLabel={t.documentPageRemove(index + 1)}
                  />
                ))}
              </ul>
            ) : (
              <p className="muted">{permissions.canEdit ? t.passportPagesEmpty : t.passportPagesEmptyHelper}</p>
            );
            return (
              <>
                {permissions.canEdit ? (
                  <FileDrop
                    buttonLabel={t.passportPagesAdd}
                    hint={t.passportPagesDrop}
                    disabled={upload.busy}
                    onFiles={(files) => void upload.start(files)}
                  >
                    {grid}
                  </FileDrop>
                ) : (
                  grid
                )}
                {viewing && (
                  <PageViewer
                    pages={pages.map(({ page }) => page).filter((page) => !isPdf(page))}
                    startAt={viewing}
                    onClose={() => setViewing(null)}
                    onDelete={permissions.canEdit ? (page) => remove(page, owner.get(page.id) ?? '') : null}
                  />
                )}
              </>
            );
          }}
        </Loaded>
      </div>
      <UploadStatus upload={upload} retryLabel={t.passportPagesRetry} />
      {removing && (
        <ConfirmDialog
          title={t.pageDeleteTitle}
          body={t.pageDeleteBody}
          confirmLabel={t.commonDelete}
          danger
          busy={removeBusy}
          error={removeError ? <Notice tone="danger">{errorMessage(t, removeError)}</Notice> : null}
          onConfirm={() => {
            setRemoveBusy(true);
            setRemoveError(null);
            remove(removing.page, removing.documentId).then(
              () => {
                setRemoveBusy(false);
                setRemoving(null);
              },
              (error: unknown) => {
                setRemoveBusy(false);
                setRemoveError(error);
              },
            );
          }}
          onCancel={() => {
            setRemoving(null);
            setRemoveError(null);
          }}
        />
      )}
    </Section>
  );
}
