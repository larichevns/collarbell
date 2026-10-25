// One record of the history (the phone app's record_detail_screen.dart): its photos and files, and every detail that
// is filled in, with "Edit" and "Delete record" for everyone but helpers. Photos and PDF files are added by dropping
// them onto the record or picking them (POST /files, then POST /care-records/{id}/files), up to ten; a photo opens
// large, a PDF in a new tab; a file is removed after a question. The record opens from Health, the passport's
// sections or a vet's weight, and its way back leads there (?from=).
import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router';
import { errorMessage, isNotFound } from '../../api/errors';
import { isPdf } from '../../api/files';
import { keys } from '../../api/keys';
import { refreshCare, useCareRecord, usePet } from '../../api/queries';
import type { CareRecord, FileLink } from '../../api/types';
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
import { recordDateLabel, weightValueLabel } from '../../lib/labels';
import { petTabPath, type PetTab } from '../pets/PetPage';

/** At most this many files per record (the server's limit). */
const MAX_FILES = 10;

/** Where a record was opened from, so its way back leads there. */
export function backTab(from: string | null): PetTab {
  return from === 'passport' || from === 'weight' ? from : 'health';
}

export function RecordPage() {
  const { id = '', recordId = '' } = useParams();
  const [search] = useSearchParams();
  const { t } = useI18n();
  const { current, permissions } = useHousehold();
  // The household the page opened in: its delete goes there, and only there does it move on afterwards.
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const stillHere = useStillHere(household);
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const pet = usePet(id);
  const record = useCareRecord(recordId);
  const [deleting, setDeleting] = useState(false);
  const [busy, setBusy] = useState(false);

  const from = search.get('from');
  const backPath = petTabPath(id, backTab(from));
  const back = { to: backPath, label: pet.data?.name ?? t.petTabHealth };
  // Deleted (here or on another phone): the old copy is not shown as if the record were there.
  if (!record.data || isNotFound(record.error)) {
    return (
      <>
        <PageHead back={back} title={t.petTabHealth} />
        {record.error ? <ErrorNotice error={record.error} onRetry={() => void record.refetch()} /> : <Loading />}
      </>
    );
  }
  const value = record.data;

  async function remove() {
    setBusy(true);
    try {
      await api.DELETE('/api/v1/care-records/{id}', { params: { path: { id: recordId } } });
    } catch (error) {
      // Deleted already, on another device: that is what was wanted.
      if (!isNotFound(error)) {
        toast(errorMessage(t, error));
        setBusy(false);
        setDeleting(false);
        return;
      }
    }
    // The plan it completed may change its "last done"; a vet's weight leaves the log.
    queryClient.removeQueries({ queryKey: keys.careRecord(household, recordId), exact: true });
    refreshCare(queryClient, household, id);
    if (stillHere()) void navigate(backPath);
  }

  return (
    <>
      <PageHead
        back={back}
        caption={t.careKind[value.kind]}
        title={value.title}
        actions={
          permissions.canEdit && (
            <>
              <Link
                to={`/pets/${id}/records/${recordId}/edit${from ? `?from=${from}` : ''}`}
                className="button button--secondary"
              >
                <Icon name="edit" />
                {t.commonEdit}
              </Link>
              <button
                type="button"
                className="button button--ghost button--danger-text"
                onClick={() => setDeleting(true)}
                disabled={busy}
              >
                <Icon name="delete" />
                {t.recordDelete}
              </button>
            </>
          )
        }
      />
      <div className="tab-sections">
        <RecordFiles record={value} />
        <Section title={t.recordDetailsTitle}>
          <RecordDetails record={value} />
        </Section>
      </div>
      {deleting && (
        <ConfirmDialog
          title={t.recordDeleteTitle}
          body={t.recordDeleteBody}
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

/** The record's photos and files: a grid, a drop zone for more, the viewer, removing one after a question. */
function RecordFiles({ record }: { record: CareRecord }) {
  const { t } = useI18n();
  const api = useApi();
  const { current, permissions } = useHousehold();
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
    void queryClient.invalidateQueries({ queryKey: keys.careRecord(current.id, record.id) });
    void queryClient.invalidateQueries({ queryKey: keys.careRecords(current.id, record.petId) });
    void queryClient.invalidateQueries({ queryKey: keys.passportRecords(current.id, record.petId) });
  };
  const upload = useUpload(api, async (links) => {
    try {
      await api.POST('/api/v1/care-records/{id}/files', {
        params: { path: { id: record.id } },
        body: { fileIds: links.map((link) => link.id) },
      });
    } finally {
      refresh();
    }
  });

  async function remove(file: FileLink) {
    setRemoveBusy(true);
    setRemoveError(null);
    try {
      await api.DELETE('/api/v1/care-records/{id}/files/{fileId}', {
        params: { path: { id: record.id, fileId: file.id } },
      });
      setRemoving(null);
    } catch (error) {
      // Gone already: that is what was wanted.
      if (isNotFound(error)) setRemoving(null);
      else setRemoveError(error);
    } finally {
      setRemoveBusy(false);
      refresh();
    }
  }

  const photos = record.files.filter((file) => !isPdf(file));
  const grid =
    record.files.length > 0 ? (
      <ul className="file-grid">
        {record.files.map((file, index) => (
          <FileTile
            key={file.id}
            file={file}
            label={t.recordFileNumber(index + 1)}
            onOpen={() => setViewing(file.id)}
            onRemove={permissions.canEdit ? () => setRemoving(file) : undefined}
            removeLabel={t.recordFileRemove(index + 1)}
          />
        ))}
      </ul>
    ) : (
      <p className="muted">{permissions.canEdit ? t.recordFilesEmpty : t.recordFilesEmptyHelper}</p>
    );

  return (
    <Section title={t.recordFilesTitle}>
      <div ref={container}>
        {permissions.canEdit ? (
          <FileDrop
            buttonLabel={t.recordFilesAdd}
            hint={t.recordFilesDrop}
            disabled={upload.busy || record.files.length >= MAX_FILES}
            onFiles={(files) => {
              const fits = record.files.length + upload.waiting + files.length <= MAX_FILES;
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
          {t.recordFilesTooMany(MAX_FILES)}
        </p>
      )}
      <UploadStatus upload={upload} />
      {viewing && <PageViewer pages={photos} startAt={viewing} onClose={() => setViewing(null)} />}
      {removing && (
        <ConfirmDialog
          title={t.recordFileRemoveTitle}
          body={t.recordFileRemoveBody}
          confirmLabel={t.commonRemove}
          danger
          busy={removeBusy}
          error={removeError ? <Notice tone="danger">{errorMessage(t, removeError)}</Notice> : null}
          onConfirm={() => void remove(removing)}
          onCancel={() => {
            setRemoving(null);
            setRemoveError(null);
          }}
        />
      )}
    </Section>
  );
}

/** Every filled-in detail, one per row. */
function RecordDetails({ record }: { record: CareRecord }) {
  const i18n = useI18n();
  const { t } = i18n;
  const text = (value: string | null | undefined) => value?.trim() || null;
  const details = record.details;
  const rows: [string, string | null, boolean][] = [
    [t.careKindLabel, t.careKind[record.kind], false],
    [t.recordPerformedOnLabel, recordDateLabel(i18n, record), false],
    [
      t.careTargetsLabel,
      record.targets.length ? record.targets.map((target) => t.vaccineTarget[target]).join(', ') : null,
      false,
    ],
    [t.careProductLabel, text(record.product), false],
    [t.careManufacturerLabel, text(record.manufacturer), false],
    [t.careBatchLabel, text(record.batchNumber), true],
    [t.careValidFromLabel, record.validFrom ? i18n.date(record.validFrom) : null, false],
    [t.careValidUntilLabel, record.validUntil ? i18n.date(record.validUntil) : null, false],
    [t.recordLaboratoryLabel, text(details?.laboratory), false],
    [t.recordReportNumberLabel, text(details?.reportNumber), true],
    [
      t.recordTiterLabel,
      details?.titerIuPerMl != null ? t.recordTiterValue(i18n.number(details.titerIuPerMl)) : null,
      false,
    ],
    [t.recordWeightLabel, record.weightKg != null ? weightValueLabel(i18n, record.weightKg) : null, false],
    [
      t.recordFitForTravel,
      details?.fitForTravel == null ? null : details.fitForTravel ? t.commonYes : t.commonNo,
      false,
    ],
    [t.careClinicLabel, text(record.clinic), false],
    [t.careVetLabel, text(record.veterinarian), false],
    [t.careNotesLabel, text(record.notes), false],
    [t.recordSourceLabel, t.recordSource[record.source], false],
  ];
  return (
    <dl className="card facts">
      {rows
        .filter((row): row is [string, string, boolean] => !!row[1])
        .map(([label, value, code]) => (
          <div key={label} className="fact">
            <dt>{label}</dt>
            <dd className={code ? 'code pre-line' : 'pre-line'}>{value}</dd>
          </div>
        ))}
    </dl>
  );
}
