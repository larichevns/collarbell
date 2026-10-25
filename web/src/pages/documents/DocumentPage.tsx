// One document (the phone app's document_detail_screen.dart): its pages and details, with "Edit details" and "Delete
// document" for everyone but helpers. Photos open large, one after another (the arrow keys turn the pages); a PDF opens
// in a new tab through its link. Pages are added by dropping files onto the pages or picking them (they go to the end:
// POST /documents/{id}/pages) and deleted one by one after a question (DELETE …/pages/{fileId}); the last page takes
// the document with it, as the server does (whether it did is the server's word: another phone may have added a page).
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { data } from '../../api/client';
import { errorMessage, isNotFound } from '../../api/errors';
import { isPdf } from '../../api/files';
import { keys } from '../../api/keys';
import { useDocument, usePet } from '../../api/queries';
import type { ApiClient } from '../../api/client';
import type { FileLink, PetDocument } from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import { FileDrop, FileTile, UploadStatus } from '../../components/Files';
import { Icon } from '../../components/Icon';
import { useStillHere } from '../../components/LeaveGuard';
import { PageViewer } from '../../components/PageViewer';
import { useToast } from '../../components/Toasts';
import { useKeepFocus } from '../../components/useKeepFocus';
import { useUpload } from '../../components/useUpload';
import { ErrorNotice, Loading, Notice, PageHead, Section } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { todayIn } from '../../lib/dates';
import { DOCUMENT_MAX, documentTitle } from '../../lib/documents';
import { petTabPath } from '../pets/PetPage';
import { DocumentDetailsDialog } from './DocumentDialogs';

export function DocumentPage() {
  const { id = '', documentId = '' } = useParams();
  const { t } = useI18n();
  const { current, permissions } = useHousehold();
  // The household the page opened in: its deletes go there, and only there does it move on afterwards.
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const stillHere = useStillHere(household);
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const pet = usePet(id);
  const document = useDocument(documentId);
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [busy, setBusy] = useState(false);

  const documentsPath = petTabPath(id, 'documents');
  const back = { to: documentsPath, label: pet.data?.name ?? t.petTabDocuments };
  // Deleted (here or on another phone): the old copy is not shown as if the document were there.
  if (!document.data || isNotFound(document.error)) {
    return (
      <>
        <PageHead back={back} title={t.petTabDocuments} />
        {document.error ? <ErrorNotice error={document.error} onRetry={() => void document.refetch()} /> : <Loading />}
      </>
    );
  }
  const value = document.data;

  /** The document is gone (deleted, or with its last page): off the screen and back to the list. */
  function gone(message?: string) {
    queryClient.removeQueries({ queryKey: keys.document(household, documentId), exact: true });
    void queryClient.invalidateQueries({ queryKey: keys.documents(household, id) });
    if (message) toast(message);
    if (stillHere()) void navigate(documentsPath);
  }

  async function remove() {
    setBusy(true);
    try {
      await api.DELETE('/api/v1/documents/{id}', { params: { path: { id: documentId } } });
    } catch (error) {
      // Deleted already, on another device: that is what was wanted.
      if (!isNotFound(error)) {
        toast(errorMessage(t, error));
        setBusy(false);
        setDeleting(false);
        return;
      }
    }
    gone();
  }

  return (
    <>
      <PageHead
        back={back}
        caption={t.documentType[value.type]}
        title={documentTitle(t, value)}
        actions={
          permissions.canEdit && (
            <>
              <button
                type="button"
                className="button button--secondary"
                onClick={() => setEditing(true)}
                // A list's copy may be older than the document: the form starts from the document's own answer.
                disabled={document.isPlaceholderData}
              >
                <Icon name="edit" />
                {t.documentEditDetails}
              </button>
              <button
                type="button"
                className="button button--ghost button--danger-text"
                onClick={() => setDeleting(true)}
                disabled={busy}
              >
                <Icon name="delete" />
                {t.documentDelete}
              </button>
            </>
          )
        }
      />
      <div className="tab-sections">
        <DocumentPages
          document={value}
          api={api}
          household={household}
          onGone={() => gone(t.documentDeletedWithPage)}
        />
        <Section title={t.documentDetailsTitle}>
          <DocumentFacts document={value} />
        </Section>
      </div>
      {editing && !document.isPlaceholderData && (
        <DocumentDetailsDialog document={value} onClose={() => setEditing(false)} />
      )}
      {deleting && (
        <ConfirmDialog
          title={t.documentDeleteTitle}
          body={t.documentDeleteBody}
          confirmLabel={t.commonDelete}
          danger
          busy={busy}
          onConfirm={() => void remove()}
          onCancel={() => setDeleting(false)}
        />
      )}
    </>
  );
}

/** The pages: a grid, a drop zone for more, the large view, deleting one after a question. */
function DocumentPages({
  document,
  api,
  household,
  onGone,
}: {
  document: PetDocument;
  api: ApiClient;
  household: string;
  onGone: () => void;
}) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const queryClient = useQueryClient();
  const [viewing, setViewing] = useState<string | null>(null);
  const [removing, setRemoving] = useState<FileLink | null>(null);
  const [removeBusy, setRemoveBusy] = useState(false);
  const [removeError, setRemoveError] = useState<unknown>(null);
  const [tooMany, setTooMany] = useState(false);
  // A file removed: the focus goes to the one now in its place.
  const container = useRef<HTMLDivElement>(null);
  useKeepFocus(container);

  const refresh = () => {
    void queryClient.invalidateQueries({ queryKey: keys.document(household, document.id) });
    if (document.petId) void queryClient.invalidateQueries({ queryKey: keys.documents(household, document.petId) });
  };
  const upload = useUpload(api, async (links) => {
    try {
      // Pages already there (a retry after a lost answer) are left out: each file belongs to one place.
      const there = new Set(document.pages.map((page) => page.id));
      const fileIds = links.map((link) => link.id).filter((fileId) => !there.has(fileId));
      if (fileIds.length) {
        await api.POST('/api/v1/documents/{id}/pages', { params: { path: { id: document.id } }, body: { fileIds } });
      }
    } finally {
      refresh();
    }
  });

  /** Deletes a page; the last one takes the document with it, which the document's answer then says (404). */
  async function removePage(page: FileLink) {
    try {
      await api.DELETE('/api/v1/documents/{id}/pages/{fileId}', {
        params: { path: { id: document.id, fileId: page.id } },
      });
    } catch (error) {
      if (!isNotFound(error)) throw error;
    }
    try {
      await data(api.GET('/api/v1/documents/{id}', { params: { path: { id: document.id } } }));
      refresh();
    } catch (error) {
      if (isNotFound(error)) onGone();
      else refresh();
    }
  }

  const photos = document.pages.filter((page) => !isPdf(page));
  const lastBody = (page: FileLink) =>
    document.pages.length === 1 && document.pages[0]?.id === page.id ? t.pageDeleteLastBody : t.pageDeleteBody;
  const grid = (
    <ul className="file-grid">
      {document.pages.map((page, index) => (
        <FileTile
          key={page.id}
          file={page}
          label={t.pageNumber(index + 1)}
          onOpen={() => setViewing(page.id)}
          onRemove={permissions.canEdit ? () => setRemoving(page) : undefined}
          removeLabel={t.documentPageRemove(index + 1)}
        />
      ))}
    </ul>
  );

  return (
    <Section title={t.documentPagesTitle}>
      <div ref={container}>
        {permissions.canEdit ? (
          <FileDrop
            buttonLabel={t.documentPagesAdd}
            hint={t.documentPagesDrop}
            disabled={upload.busy}
            onFiles={(files) => {
              const fits = document.pages.length + upload.waiting + files.length <= DOCUMENT_MAX.pages;
              setTooMany(!fits);
              if (fits) void upload.start(files);
            }}
          >
            {grid}
          </FileDrop>
        ) : (
          grid
        )}
      </div>
      {tooMany && (
        <p className="field-error" role="alert">
          <Icon name="error" size={16} />
          {t.documentPagesTooMany(DOCUMENT_MAX.pages)}
        </p>
      )}
      <UploadStatus upload={upload} />
      {viewing && (
        <PageViewer
          pages={photos}
          startAt={viewing}
          onClose={() => setViewing(null)}
          onDelete={permissions.canEdit ? removePage : null}
          deleteBody={lastBody}
        />
      )}
      {removing && (
        <ConfirmDialog
          title={t.pageDeleteTitle}
          body={lastBody(removing)}
          confirmLabel={t.commonDelete}
          danger
          busy={removeBusy}
          error={removeError ? <Notice tone="danger">{errorMessage(t, removeError)}</Notice> : null}
          onConfirm={() => {
            setRemoveBusy(true);
            setRemoveError(null);
            removePage(removing).then(
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

function DocumentFacts({ document }: { document: PetDocument }) {
  const i18n = useI18n();
  const { t } = i18n;
  const { current } = useHousehold();
  const rows: [string, string | null][] = [
    [t.documentTypeLabel, t.documentType[document.type]],
    [t.documentDateLabel, document.documentDate ? i18n.date(document.documentDate) : null],
    [t.documentPagesTitle, t.documentPageCount(document.pages.length)],
    [t.documentAddedOnLabel, i18n.date(todayIn(current.timeZone, new Date(document.createdAt)))],
    [t.documentNotesLabel, document.notes?.trim() || null],
  ];
  return (
    <dl className="card facts">
      {rows
        .filter((row): row is [string, string] => !!row[1])
        .map(([label, value]) => (
          <div key={label} className="fact">
            <dt>{label}</dt>
            <dd className="pre-line">{value}</dd>
          </div>
        ))}
    </dl>
  );
}
