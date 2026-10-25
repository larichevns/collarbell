// History from the paper passport, many records at once: what the big screen is for. A table where each row is a
// record (its type, date, product, batch, valid from and until, the vet; for a vaccination what it protects against;
// for a treatment before travel its hour). Tab moves to the next field; Enter starts a new row below the last one (or
// moves down a row), Shift+Enter moves up. "Save" checks every row like the record form first: while a row has a
// mistake the app can see, nothing is sent. Then each row is one POST /pets/{id}/care-records with its own request id,
// one after another, with the progress shown; a saved row leaves the table, a refused one stays with the reason under
// it and keeps its request id, so saving again adds nothing twice. On a narrow screen each row is a card.
import { useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState, type FormEvent, type KeyboardEvent } from 'react';
import { useNavigate, useParams } from 'react-router';
import { ApiError, data } from '../../api/client';
import { errorMessage, fieldErrorsOf, isNotFound } from '../../api/errors';
import { refreshCare, usePet } from '../../api/queries';
import type { CareKind, Pet, VaccineTarget } from '../../api/types';
import { Icon } from '../../components/Icon';
import { useKeepFocus } from '../../components/useKeepFocus';
import { useLeaveGuard, useStillHere } from '../../components/LeaveGuard';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loading, PageHead, Spinner } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { CARE_KINDS, EARLIEST_CARE_DATE, latestDueDate, offeredTargets } from '../../lib/care';
import { petTabPath } from '../pets/PetPage';
import {
  BULK_FIELDS,
  newRow,
  rowFields,
  rowHolds,
  rowProblems,
  rowRequest,
  type BulkField,
  type BulkRow,
} from './bulk';

/** The columns the keys move between, in order. */
type Column = 'kind' | 'date' | 'time' | 'product' | 'batch' | 'validFrom' | 'validUntil' | 'vet';

/** What went wrong with a row when it was sent: the server's fields, or a reason in words. */
interface RowFailure {
  fields: Partial<Record<BulkField, true>>;
  message: string;
}

export function BulkEntryPage() {
  const { id = '' } = useParams();
  const { t } = useI18n();
  const pet = usePet(id);
  if (pet.data && !isNotFound(pet.error)) return <BulkEntry pet={pet.data} />;
  return (
    <>
      <PageHead back={{ to: petTabPath(id, 'health'), label: t.petTabHealth }} title={t.bulkTitle} />
      {pet.error ? <ErrorNotice error={pet.error} onRetry={() => void pet.refetch()} /> : <Loading />}
    </>
  );
}

function BulkEntry({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const { current } = useHousehold();
  const shownApi = useApi();
  const [{ api, household }] = useState({ api: shownApi, household: current.id });
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const today = useHouseholdDate();
  const table = useRef<HTMLDivElement>(null);
  // A row removed: the focus goes to the row now in its place.
  useKeepFocus(table, { item: 'fieldset.bulk-row' });
  const [rows, setRows] = useState<BulkRow[]>(() => [newRow()]);
  const [checked, setChecked] = useState(false);
  const [failures, setFailures] = useState<ReadonlyMap<string, RowFailure>>(new Map());
  const [saving, setSaving] = useState<{ current: number; total: number } | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const healthPath = petTabPath(pet.id, 'health');
  const filled = rows.filter((row) => row.touched);
  const { allowLeave } = useLeaveGuard(filled.length > 0, saving !== null);
  const stillHere = useStillHere(household);

  /** Focuses a field of a row once it is on screen: [data-row][data-col]. */
  function focusCell(row: number, column: Column) {
    window.requestAnimationFrame(() => {
      const cells = table.current?.querySelectorAll<HTMLElement>(`[data-row="${row}"] [data-col]`);
      const cell =
        table.current?.querySelector<HTMLElement>(`[data-row="${row}"] [data-col="${column}"]`) ??
        cells?.item(column === 'kind' ? 0 : 1);
      cell?.focus();
    });
  }

  function update(key: string, change: Partial<BulkRow>) {
    setRows((old) => old.map((row) => (row.key === key ? { ...row, ...change, touched: true } : row)));
    // A row changed after a refusal: its old reasons no longer apply.
    setFailures((old) => {
      if (!old.has(key)) return old;
      const next = new Map(old);
      next.delete(key);
      return next;
    });
  }

  function addRow(focus = true) {
    setRows((old) => [...old, newRow(old.at(-1))]);
    if (focus) focusCell(rows.length, 'date');
  }

  function removeRow(key: string) {
    setRows((old) => {
      const rest = old.filter((row) => row.key !== key);
      return rest.length ? rest : [newRow()];
    });
  }

  /** Enter: the same field a row down, or a new row after the last; Shift+Enter: a row up. */
  function onKey(event: KeyboardEvent<HTMLElement>, index: number, column: Column) {
    if (event.key !== 'Enter' || event.altKey || event.ctrlKey || event.metaKey) return;
    event.preventDefault();
    if (event.shiftKey) {
      if (index > 0) focusCell(index - 1, column);
      return;
    }
    if (index === rows.length - 1) addRow();
    else focusCell(index + 1, column);
  }

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (saving) return;
    setChecked(true);
    setFailure(null);
    const toSave = rows.filter((row) => row.touched);
    if (!toSave.length) {
      setFailure(t.bulkNothing);
      return;
    }
    if (toSave.some((row) => Object.keys(rowProblems(t, row, today)).length > 0)) {
      setFailure(t.bulkCheckRows);
      focusFirstProblem();
      return;
    }

    const failed = new Map<string, RowFailure>();
    let saved = 0;
    for (const [index, row] of toSave.entries()) {
      setSaving({ current: index + 1, total: toSave.length });
      const body = rowRequest(t, row);
      try {
        const record = await data(
          api.POST('/api/v1/pets/{petId}/care-records', { params: { path: { petId: pet.id } }, body }),
        );
        // A retry after a lost answer gets the record as the first try sent it: a correction since then goes after it.
        if (!rowHolds(record, body)) {
          await api.PUT('/api/v1/care-records/{id}', {
            params: { path: { id: record.id } },
            body: { ...body, requestId: null },
          });
        }
        saved += 1;
        setRows((old) => old.filter((each) => each.key !== row.key));
      } catch (error) {
        if (isNotFound(error)) {
          // The pet was deleted elsewhere: there is nowhere to save to.
          refreshCare(queryClient, household, pet.id);
          setSaving(null);
          toast(t.careGonePet);
          allowLeave();
          if (stillHere()) void navigate('/pets');
          return;
        }
        const fields = fieldErrorsOf(error);
        const placed = Object.keys(fields).length > 0 && Object.keys(fields).every((field) => isBulkField(field));
        // No answer: the row may have been saved all the same; "Save" again checks, without adding it twice.
        const unanswered = error instanceof ApiError && error.status === 0;
        failed.set(row.key, {
          fields: placed ? Object.fromEntries(Object.keys(fields).map((field) => [field, true])) : {},
          message: unanswered
            ? t.bulkRowNoAnswer
            : t.bulkRowNotSaved(placed ? t.formCheckFields : errorMessage(t, error)),
        });
        // No answer, or no right: the rows after it would only fail the same way. They stay, with the same reason.
        if (error instanceof ApiError && (error.status === 0 || error.status === 401 || error.status === 403)) {
          for (const rest of toSave.slice(index + 1)) {
            failed.set(rest.key, { fields: {}, message: t.bulkRowNotSaved(errorMessage(t, error)) });
          }
          break;
        }
      }
    }
    setSaving(null);
    setFailures(failed);
    refreshCare(queryClient, household, pet.id);
    if (failed.size === 0) {
      toast(t.bulkSaved(saved));
      allowLeave();
      if (stillHere()) void navigate(healthPath);
      return;
    }
    setFailure(t.bulkNotSaved(failed.size));
    focusFirstProblem();
  }

  function focusFirstProblem() {
    window.requestAnimationFrame(() => {
      table.current?.querySelector<HTMLElement>('[aria-invalid="true"], .bulk-row-error')?.focus();
    });
  }

  const busy = saving !== null;
  return (
    <>
      <PageHead back={{ to: healthPath, label: pet.name }} title={t.bulkTitle} />
      <p className="muted bulk-intro">{t.bulkIntro}</p>
      <form className="bulk" noValidate onSubmit={(event) => void save(event)} aria-busy={busy || undefined}>
        <fieldset className="bulk-fieldset" disabled={busy}>
          <div className="bulk-table" ref={table}>
            <div className="bulk-head" aria-hidden="true">
              <span>{t.careKindLabel}</span>
              <span>{t.recordPerformedOnLabel}</span>
              <span>{t.careProductLabel}</span>
              <span>{t.careBatchLabel}</span>
              <span>{t.careValidFromLabel}</span>
              <span>{t.careValidUntilLabel}</span>
              <span>{t.careVetLabel}</span>
              <span />
            </div>
            {rows.map((row, index) => (
              <BulkRowFields
                key={row.key}
                pet={pet}
                row={row}
                index={index}
                today={today}
                problems={checked && row.touched ? rowProblems(t, row, today) : {}}
                failure={failures.get(row.key) ?? null}
                onChange={(change) => update(row.key, change)}
                onRemove={() => removeRow(row.key)}
                onKey={(event, column) => onKey(event, index, column)}
              />
            ))}
          </div>
          <button type="button" className="button button--secondary" onClick={() => addRow()}>
            <Icon name="add" size={18} />
            {t.bulkAddRow}
          </button>
        </fieldset>
        <div className="form-foot">
          {saving && (
            <p className="bulk-progress" role="status">
              <Spinner />
              {t.bulkSaving(saving.current, saving.total)}
            </p>
          )}
          {failure && !saving && (
            <p className="form-error" role="alert">
              <Icon name="error" size={18} />
              {failure}
            </p>
          )}
          <button type="submit" className="button button--primary" disabled={busy}>
            {busy && <Spinner />}
            {busy ? t.commonSaving : t.bulkSave(Math.max(filled.length, 1))}
          </button>
          <button
            type="button"
            className="button button--ghost"
            onClick={() => void navigate(healthPath)}
            disabled={busy}
          >
            {t.commonCancel}
          </button>
        </div>
      </form>
    </>
  );
}

function isBulkField(field: string): field is BulkField {
  return (BULK_FIELDS as readonly string[]).includes(field);
}

/** One row: a group of fields named "Record 3", a cell each, the targets of a vaccination under them. */
function BulkRowFields({
  pet,
  row,
  index,
  today,
  problems,
  failure,
  onChange,
  onRemove,
  onKey,
}: {
  pet: Pet;
  row: BulkRow;
  index: number;
  today: string;
  problems: Partial<Record<BulkField, string>>;
  failure: RowFailure | null;
  onChange: (change: Partial<BulkRow>) => void;
  onRemove: () => void;
  onKey: (event: KeyboardEvent<HTMLElement>, column: Column) => void;
}) {
  const { t } = useI18n();
  const id = useId();
  const has = rowFields(row.kind);
  const number = index + 1;
  /** The app's own word on a field, else the server's. */
  const errorOf = (field: BulkField) => problems[field] ?? (failure?.fields[field] ? t.formServerFieldError : null);

  /** A cell: its label (seen on a narrow screen, else the table's head says it), the input, its error. */
  const cell = (
    column: Column,
    field: BulkField,
    label: string,
    input: (props: {
      id: string;
      'data-col': Column;
      'aria-invalid'?: true;
      'aria-describedby'?: string;
      onKeyDown: (event: KeyboardEvent<HTMLElement>) => void;
    }) => React.ReactNode,
  ) => {
    const error = errorOf(field);
    const inputId = `${id}-${column}`;
    return (
      <div className={`bulk-cell bulk-cell--${column}`}>
        <label className="bulk-label" htmlFor={inputId}>
          {label}
        </label>
        {input({
          id: inputId,
          'data-col': column,
          'aria-invalid': error ? true : undefined,
          'aria-describedby': error ? `${inputId}-error` : undefined,
          onKeyDown: (event) => onKey(event, column),
        })}
        {error && (
          <p className="field-error" id={`${inputId}-error`}>
            <Icon name="error" size={16} />
            {error}
          </p>
        )}
      </div>
    );
  };
  const none = (column: Column, label: string) => (
    <div className={`bulk-cell bulk-cell--${column} bulk-cell--none`}>
      <span className="bulk-label">{label}</span>
      <span aria-hidden="true">—</span>
      <span className="visually-hidden">{t.bulkNotForKind}</span>
    </div>
  );

  return (
    <fieldset
      className={`bulk-row${failure || Object.keys(problems).length ? ' bulk-row--invalid' : ''}`}
      data-row={index}
      aria-describedby={failure ? `${id}-failure` : undefined}
    >
      <legend className="bulk-legend">{t.bulkRowLabel(number)}</legend>
      {cell('kind', 'kind', t.careKindLabel, (props) => (
        <select
          {...props}
          className="input input--compact"
          value={row.kind}
          onChange={(event) => onChange({ kind: event.target.value as CareKind })}
        >
          {CARE_KINDS.map((kind) => (
            <option key={kind} value={kind}>
              {t.careKind[kind]}
            </option>
          ))}
        </select>
      ))}
      <div className="bulk-cell-group bulk-cell--when">
        {cell('date', 'performedOn', t.recordPerformedOnLabel, (props) => (
          <input
            {...props}
            className="input input--compact"
            type="date"
            min={EARLIEST_CARE_DATE}
            max={today}
            value={row.performedOn}
            onChange={(event) => onChange({ performedOn: event.target.value })}
          />
        ))}
        {has.time &&
          cell('time', 'performedTime', t.careTimeLabel, (props) => (
            <input
              {...props}
              className="input input--compact"
              type="time"
              value={row.time}
              onChange={(event) => onChange({ time: event.target.value })}
            />
          ))}
      </div>
      {has.product
        ? cell('product', 'product', t.careProductLabel, (props) => (
            <input
              {...props}
              className="input input--compact"
              value={row.product}
              onChange={(event) => onChange({ product: event.target.value })}
            />
          ))
        : none('product', t.careProductLabel)}
      {has.product
        ? cell('batch', 'batchNumber', t.careBatchLabel, (props) => (
            <input
              {...props}
              className="input input--compact input--code"
              spellCheck={false}
              value={row.batch}
              onChange={(event) => onChange({ batch: event.target.value })}
            />
          ))
        : none('batch', t.careBatchLabel)}
      {has.validity
        ? cell('validFrom', 'validFrom', t.careValidFromLabel, (props) => (
            <input
              {...props}
              className="input input--compact"
              type="date"
              min={row.performedOn || EARLIEST_CARE_DATE}
              max={latestDueDate(today)}
              value={row.validFrom}
              onChange={(event) => onChange({ validFrom: event.target.value })}
            />
          ))
        : none('validFrom', t.careValidFromLabel)}
      {has.validity
        ? cell('validUntil', 'validUntil', t.careValidUntilLabel, (props) => (
            <input
              {...props}
              className="input input--compact"
              type="date"
              min={row.performedOn || EARLIEST_CARE_DATE}
              max={latestDueDate(today)}
              value={row.validUntil}
              onChange={(event) => onChange({ validUntil: event.target.value })}
            />
          ))
        : none('validUntil', t.careValidUntilLabel)}
      {cell('vet', 'veterinarian', t.careVetLabel, (props) => (
        <input
          {...props}
          className="input input--compact"
          value={row.vet}
          onChange={(event) => onChange({ vet: event.target.value })}
        />
      ))}
      <div className="bulk-cell bulk-cell--remove">
        <button
          type="button"
          className="icon-button"
          aria-label={t.bulkRemoveRow(number)}
          title={t.bulkRemoveRow(number)}
          onClick={onRemove}
        >
          <Icon name="delete" />
        </button>
      </div>
      {has.targets && (
        <Targets
          species={pet.species}
          chosen={row.targets}
          error={errorOf('targets')}
          onChange={(targets) => onChange({ targets })}
        />
      )}
      {failure && (
        <p className="field-error bulk-row-error" id={`${id}-failure`} tabIndex={-1}>
          <Icon name="error" size={16} />
          {failure.message}
        </p>
      )}
    </fieldset>
  );
}

/** What a vaccination protects against: compact pills across the row. */
function Targets({
  species,
  chosen,
  error,
  onChange,
}: {
  species: Pet['species'];
  chosen: VaccineTarget[];
  error: string | null;
  onChange: (targets: VaccineTarget[]) => void;
}) {
  const { t } = useI18n();
  const id = useId();
  return (
    <fieldset
      className="bulk-targets choice-group"
      data-invalid={error ? true : undefined}
      aria-describedby={error ? `${id}-error` : undefined}
    >
      <legend className="bulk-targets-label">{t.careTargetsLabel}</legend>
      <div className="choices">
        {offeredTargets(species, chosen).map((target) => (
          <label key={target} className="choice">
            <input
              type="checkbox"
              checked={chosen.includes(target)}
              onChange={(event) =>
                onChange(event.target.checked ? [...chosen, target] : chosen.filter((each) => each !== target))
              }
            />
            <span className="choice-pill choice-pill--sm">
              {chosen.includes(target) && <Icon name="check" size={14} />}
              {t.vaccineTarget[target]}
            </span>
          </label>
        ))}
      </div>
      {error && (
        <p className="field-error" id={`${id}-error`}>
          <Icon name="error" size={16} />
          {error}
        </p>
      )}
    </fieldset>
  );
}
