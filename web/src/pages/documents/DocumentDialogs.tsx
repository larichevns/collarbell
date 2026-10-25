// The document forms (the phone app's document_form_screen.dart), as dialogs over the Documents tab and a document's
// page: a new document from the files dropped or picked (its pages in that order, more can be added or removed), with
// its type, title, date and notes; and a document's details. A new document's files are uploaded first, one after
// another, then the document is made with its pages (POST /pets/{id}/documents). The API has no request id for a new
// document yet: a try after one whose answer may have been lost first looks for the document it made (the one holding
// any of its files: a file belongs to one place only), and brings it up to what the dialog holds now: pages added or
// removed since, the details changed since.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { uploadFile } from '../../api/files';
import { keys } from '../../api/keys';
import type { DocumentRequest, DocumentType, FileLink, Pet, PetDocument } from '../../api/types';
import { Dialog, DialogBody, DialogCancel, DialogFoot, DialogForm } from '../../components/Dialog';
import { FileDrop, LocalFileTile, UploadProgress } from '../../components/Files';
import { DateField, SelectField, TextField, useFocusFirstError } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { useToast } from '../../components/Toasts';
import { Spinner } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { DOCUMENT_MAX, DOCUMENT_TYPES } from '../../lib/documents';
import { useKeepFocus } from '../../components/useKeepFocus';

const FIELDS = ['type', 'title', 'documentDate', 'notes', 'fileIds'];

interface Details {
  type: DocumentType;
  title: string;
  date: string;
  notes: string;
}

/** The type, title, date and notes: the fields both dialogs have. */
function DetailsFields({
  values,
  onChange,
  errors,
  today,
}: {
  values: Details;
  onChange: (change: Partial<Details>) => void;
  errors: Record<string, string | null>;
  today: string;
}) {
  const { t } = useI18n();
  return (
    <>
      <div className="form-row">
        <SelectField
          label={t.documentTypeLabel}
          value={values.type}
          options={DOCUMENT_TYPES.map((type) => ({ value: type, label: t.documentType[type] }))}
          onChange={(type) => onChange({ type })}
          error={errors.type}
        />
        <DateField
          label={t.documentDateLabel}
          value={values.date}
          max={today}
          onChange={(date) => onChange({ date })}
          error={errors.documentDate}
        />
      </div>
      <TextField
        label={t.documentTitleLabel}
        placeholder={t.documentTitleHint}
        value={values.title}
        onChange={(title) => onChange({ title })}
        error={errors.title}
      />
      <TextField
        label={t.documentNotesLabel}
        value={values.notes}
        rows={3}
        onChange={(notes) => onChange({ notes })}
        error={errors.notes}
      />
    </>
  );
}

/** The checks of the details: the server's limits, and no date after today. */
function detailsProblems(
  t: ReturnType<typeof useI18n>['t'],
  values: Details,
  today: string,
  refused: Record<string, string[]>,
) {
  const server = (field: string) => (refused[field] ? t.formServerFieldError : null);
  return {
    type: server('type'),
    title: values.title.trim().length > DOCUMENT_MAX.title ? t.formTooLong(DOCUMENT_MAX.title) : server('title'),
    documentDate: values.date > today ? t.dateInFuture : server('documentDate'),
    notes: values.notes.trim().length > DOCUMENT_MAX.notes ? t.formTooLong(DOCUMENT_MAX.notes) : server('notes'),
  };
}

interface DraftPage {
  key: string;
  file: File;
  /** A photo is shown from memory until it is uploaded. */
  preview: string | null;
}

const draftOf = (file: File): DraftPage => ({
  key: crypto.randomUUID(),
  file,
  preview: file.type.startsWith('image/') ? URL.createObjectURL(file) : null,
});

export function NewDocumentDialog({ pet, files, onClose }: { pet: Pet; files: File[]; onClose: () => void }) {
  const { t } = useI18n();
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  const toast = useToast();
  const today = useHouseholdDate();
  const body = useRef<HTMLDivElement>(null);
  const [pages, setPages] = useState<DraftPage[]>(() => files.map(draftOf));
  const [values, setValues] = useState<Details>({ type: 'Other', title: '', date: '', notes: '' });
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null);
  const [submitted, setSubmitted] = useState(0);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  /** The pages uploaded so far, by draft: a try again doesn't upload them twice. */
  const uploaded = useRef(new Map<string, FileLink>());
  /** A try has been sent: its answer may have been lost. */
  const tried = useRef(false);
  /** Every file sent by a try: the document a lost answer made holds some of them, whatever was changed since. */
  const sent = useRef(new Set<string>());
  useFocusFirstError(body, submitted);
  // A page removed: the focus goes to the page now in its place, or to "Add pages" when none is left.
  const pagesBox = useRef<HTMLDivElement>(null);
  useKeepFocus(pagesBox, { fallback: () => pagesBox.current?.querySelector<HTMLElement>('.file-drop-actions button') });

  // The previews are let go when their page goes, and when the dialog closes.
  const previews = useRef(new Set<string>());
  useEffect(() => {
    for (const page of pages) if (page.preview) previews.current.add(page.preview);
  }, [pages]);
  useEffect(
    () => () => {
      for (const preview of previews.current) URL.revokeObjectURL(preview);
    },
    [],
  );

  function problems(refused: Record<string, string[]>) {
    return {
      ...detailsProblems(t, values, today, refused),
      fileIds:
        pages.length === 0
          ? t.documentPagesRequired
          : pages.length > DOCUMENT_MAX.pages
            ? t.documentPagesTooMany(DOCUMENT_MAX.pages)
            : refused.fileIds
              ? t.formServerFieldError
              : null,
    };
  }
  const errors = problems(submitted > 0 ? serverFields : {});
  const pagesError = submitted > 0 || pages.length > DOCUMENT_MAX.pages ? errors.fileIds : null;

  function finished() {
    void queryClient.invalidateQueries({ queryKey: keys.documents(current.id, pet.id) });
    toast(t.documentAdded);
    onClose();
  }

  /** A page taken out before saving: its picture in memory goes with it. */
  function removePage(page: DraftPage) {
    setPages((old) => old.filter((each) => each !== page));
    if (page.preview) {
      URL.revokeObjectURL(page.preview);
      previews.current.delete(page.preview);
    }
  }

  async function save() {
    setSubmitted((value) => value + 1);
    setServerFields({});
    setFailure(null);
    if (Object.values(problems({})).some(Boolean)) {
      setFailure(t.formCheckFields);
      return;
    }
    setBusy(true);
    try {
      const toUpload = pages.filter((page) => !uploaded.current.has(page.key));
      for (const [index, page] of toUpload.entries()) {
        setProgress({ done: index, total: toUpload.length });
        uploaded.current.set(page.key, await uploadFile(api, page.file));
      }
      setProgress(null);
      const fileIds = pages.map((page) => uploaded.current.get(page.key)!.id);
      const clean = (value: string) => value.trim() || null;
      const details = {
        type: values.type,
        title: clean(values.title),
        documentDate: values.date || null,
        notes: clean(values.notes),
      };
      if (tried.current) {
        // An earlier try may have made the document and lost the answer: the one holding any file a try sent is it,
        // also when its pages were changed since (catchUp then takes out the ones no longer here).
        const existing = await data(api.GET('/api/v1/pets/{petId}/documents', { params: { path: { petId: pet.id } } }));
        const made = existing.find((document) => document.pages.some((page) => sent.current.has(page.id)));
        if (made) {
          await catchUp(made, fileIds, details);
          finished();
          return;
        }
      }
      tried.current = true;
      for (const fileId of fileIds) sent.current.add(fileId);
      await api.POST('/api/v1/pets/{petId}/documents', {
        params: { path: { petId: pet.id } },
        body: { ...details, fileIds },
      });
      finished();
    } catch (error) {
      setProgress(null);
      if (isNotFound(error)) {
        toast(t.careGonePet);
        onClose();
        return;
      }
      const fields = fieldErrorsOf(error);
      const placed = Object.keys(fields).length > 0 && Object.keys(fields).every((field) => FIELDS.includes(field));
      setServerFields(placed ? fields : {});
      setFailure(placed ? t.formCheckFields : errorMessage(t, error));
      if (placed) setSubmitted((value) => value + 1);
    } finally {
      setBusy(false);
    }
  }

  /** The document a lost answer made, brought up to the dialog: pages added since, pages taken out, the details. */
  async function catchUp(made: PetDocument, fileIds: string[], details: Omit<DocumentRequest, 'fileIds'>) {
    const there = new Set(made.pages.map((page) => page.id));
    const missing = fileIds.filter((fileId) => !there.has(fileId));
    if (missing.length) {
      await api.POST('/api/v1/documents/{id}/pages', { params: { path: { id: made.id } }, body: { fileIds: missing } });
    }
    // After the additions: a document never loses its last page here.
    for (const page of made.pages) {
      if (fileIds.includes(page.id)) continue;
      await api.DELETE('/api/v1/documents/{id}/pages/{fileId}', { params: { path: { id: made.id, fileId: page.id } } });
    }
    const same =
      made.type === details.type &&
      made.title === details.title &&
      made.documentDate === details.documentDate &&
      made.notes === details.notes;
    if (!same) await api.PUT('/api/v1/documents/{id}', { params: { path: { id: made.id } }, body: details });
  }

  return (
    <Dialog title={t.documentFormAddTitle} onClose={onClose} busy={busy} changed wide>
      <DialogForm onSubmit={() => void save()} busy={busy}>
        <DialogBody>
          <div className="form-stack" ref={body}>
            <DetailsFields
              values={values}
              onChange={(change) => setValues((old) => ({ ...old, ...change }))}
              errors={errors}
              today={today}
            />
            <fieldset className="choice-group" data-invalid={pagesError ? true : undefined}>
              <legend className="field-label">{t.documentPagesTitle}</legend>
              <div ref={pagesBox}>
                <FileDrop
                  buttonLabel={t.documentPagesAdd}
                  hint={t.documentPagesDrop}
                  disabled={busy}
                  onFiles={(more) => setPages((old) => [...old, ...more.map(draftOf)])}
                >
                  {pages.length > 0 && (
                    <ul className="file-grid">
                      {pages.map((page, index) => (
                        <LocalFileTile
                          key={page.key}
                          file={page.file}
                          preview={page.preview}
                          label={t.pageNumber(index + 1)}
                          removeLabel={t.documentPageRemove(index + 1)}
                          onRemove={busy ? undefined : () => removePage(page)}
                        />
                      ))}
                    </ul>
                  )}
                </FileDrop>
              </div>
              {pagesError && (
                <p className="field-error">
                  <Icon name="error" size={16} />
                  {pagesError}
                </p>
              )}
            </fieldset>
          </div>
        </DialogBody>
        <DialogFoot>
          {progress && <UploadProgress done={progress.done} total={progress.total} />}
          {failure && !progress && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          <DialogCancel disabled={busy} />
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {busy ? t.commonSaving : t.commonSave}
          </button>
        </DialogFoot>
      </DialogForm>
    </Dialog>
  );
}

/** A document's type, title, date and notes (PUT /documents/{id}: the pages stay as they are). */
export function DocumentDetailsDialog({ document, onClose }: { document: PetDocument; onClose: () => void }) {
  const { t } = useI18n();
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  const toast = useToast();
  const today = useHouseholdDate();
  const body = useRef<HTMLDivElement>(null);
  const [values, setValues] = useState<Details>(() => ({
    type: document.type,
    title: document.title ?? '',
    date: document.documentDate ?? '',
    notes: document.notes ?? '',
  }));
  const [opened] = useState(() => JSON.stringify(values));
  const [busy, setBusy] = useState(false);
  const [submitted, setSubmitted] = useState(0);
  const [serverFields, setServerFields] = useState<Record<string, string[]>>({});
  const [failure, setFailure] = useState<string | null>(null);
  useFocusFirstError(body, submitted);
  const errors = detailsProblems(t, values, today, serverFields);

  async function save() {
    setSubmitted((value) => value + 1);
    setServerFields({});
    setFailure(null);
    if (Object.values(detailsProblems(t, values, today, {})).some(Boolean)) {
      setFailure(t.formCheckFields);
      return;
    }
    setBusy(true);
    const clean = (value: string) => value.trim() || null;
    try {
      await api.PUT('/api/v1/documents/{id}', {
        params: { path: { id: document.id } },
        body: {
          type: values.type,
          title: clean(values.title),
          documentDate: values.date || null,
          notes: clean(values.notes),
        },
      });
      onClose();
    } catch (error) {
      if (isNotFound(error)) {
        toast(t.documentGone);
        onClose();
        return;
      }
      const fields = fieldErrorsOf(error);
      const placed = Object.keys(fields).length > 0 && Object.keys(fields).every((field) => FIELDS.includes(field));
      setServerFields(placed ? fields : {});
      setFailure(placed ? t.formCheckFields : errorMessage(t, error));
      if (placed) setSubmitted((value) => value + 1);
    } finally {
      setBusy(false);
      void queryClient.invalidateQueries({ queryKey: keys.document(current.id, document.id) });
      if (document.petId) void queryClient.invalidateQueries({ queryKey: keys.documents(current.id, document.petId) });
    }
  }

  return (
    <Dialog title={t.documentFormEditTitle} onClose={onClose} busy={busy} changed={JSON.stringify(values) !== opened}>
      <DialogForm onSubmit={() => void save()} busy={busy}>
        <DialogBody>
          <div className="form-stack" ref={body}>
            <DetailsFields
              values={values}
              onChange={(change) => setValues((old) => ({ ...old, ...change }))}
              errors={errors}
              today={today}
            />
          </div>
        </DialogBody>
        <DialogFoot>
          {failure && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          <DialogCancel disabled={busy} />
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {busy ? t.commonSaving : t.commonSave}
          </button>
        </DialogFoot>
      </DialogForm>
    </Dialog>
  );
}
