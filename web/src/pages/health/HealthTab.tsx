// The Health tab (the phone app's health_tab.dart): the care plan grouped by status (overdue, due soon, upcoming, then
// finished or paused, folded), each with when it is due and "Done"; and the history of records, newest first, with a
// filter by kind. Helpers mark plans done; adding and changing is for the others. Past records are added one by one,
// or many at once from the paper passport (the bulk entry, a page of its own); with AI set up on the server, also read
// from a vet document or a note written in words, whose drafts wait at the top until they are checked. With no plans
// yet, "Add plan" is the tab's main button under the empty text; with no records yet, the ways to add them are action
// cards there instead of the buttons beside "History".
import { useId, useRef, useState } from 'react';
import { Link } from 'react-router';
import { useAiStatus, useCarePlans, useCareRecords } from '../../api/queries';
import type { CareKind, CarePlan, CareRecord, Pet } from '../../api/types';
import { ActionCard, ActionList } from '../../components/ActionCard';
import { DueLine } from '../../components/DueLine';
import { Icon } from '../../components/Icon';
import { CARE_KIND_ICONS } from '../../components/kindIcons';
import { ChoiceGroup } from '../../components/fields';
import { Loaded, Section } from '../../components/ui';
import { useKeepFocus } from '../../components/useKeepFocus';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { CARE_KINDS, groupPlans } from '../../lib/care';
import { intervalLabel, planStatusLabel, recordDateLabel } from '../../lib/labels';
import { AiHistoryActions, NoteEntry } from '../scans/ScanCards';
import { DoneDialog } from '../today/DoneDialog';

export function HealthTab({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const plans = useCarePlans(pet.id);
  const records = useCareRecords(pet.id);
  // Empty (or still loading): the ways to add are under the empty text, not beside the title.
  const hasPlans = plans.data ? plans.data.length > 0 : !!plans.error;
  const hasRecords = records.data ? records.data.length > 0 : !!records.error;
  return (
    <div className="tab-sections">
      {/* Notes written here wait here, like scans on the Passport tab. */}
      {permissions.canEdit && <NoteEntry pet={pet} />}
      <Section
        title={t.healthPlansTitle}
        action={
          permissions.canEdit &&
          hasPlans && (
            <Link to={`/pets/${pet.id}/plans/new`} className="button button--secondary">
              <Icon name="add" size={18} />
              {t.healthPlansAdd}
            </Link>
          )
        }
      >
        <Loaded query={plans}>{(value) => <Plans pet={pet} plans={value} />}</Loaded>
      </Section>
      <Section
        title={t.healthHistoryTitle}
        action={
          permissions.canEdit &&
          hasRecords && (
            <>
              <AiHistoryActions pet={pet} />
              <Link to={`/pets/${pet.id}/records/import`} className="button button--secondary">
                <Icon name="playlist_add" size={18} />
                {t.bulkLink}
              </Link>
              <Link to={`/pets/${pet.id}/records/new`} className="button button--secondary">
                <Icon name="add" size={18} />
                {t.healthHistoryAdd}
              </Link>
            </>
          )
        }
      >
        <Loaded query={records}>{(value) => <History pet={pet} records={value} />}</Loaded>
      </Section>
    </div>
  );
}

function Plans({ pet, plans }: { pet: Pet; plans: CarePlan[] }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const [doing, setDoing] = useState<CarePlan | null>(null);
  const [showInactive, setShowInactive] = useState(false);
  const inactiveId = useId();
  // Done: the plan moves to another group (or away), and the focus goes to the plan now in its place.
  const container = useRef<HTMLDivElement>(null);
  useKeepFocus(container);

  if (plans.length === 0) {
    if (!permissions.canEdit) return <p className="muted">{t.healthPlansEmptyHelper}</p>;
    return (
      <div className="empty-section">
        <p className="muted">{t.healthPlansEmpty}</p>
        <Link to={`/pets/${pet.id}/plans/new`} className="button button--primary">
          <Icon name="add" />
          {t.healthPlansAdd}
        </Link>
      </div>
    );
  }
  const groups = groupPlans(plans);
  const inactive = groups.find(([status]) => status === 'Inactive')?.[1] ?? [];
  const titles = { Overdue: t.careStatusOverdue, DueSoon: t.careStatusDueSoon, Upcoming: t.careStatusUpcoming };
  const list = (items: CarePlan[]) => (
    <ul className="card card--list rows">
      {items.map((plan) => (
        <PlanRow key={plan.id} pet={pet} plan={plan} onDone={() => setDoing(plan)} />
      ))}
    </ul>
  );

  return (
    <div className="plan-groups" ref={container}>
      {groups.map(([status, items]) =>
        status === 'Inactive' ? null : (
          <div key={status} className="plan-group">
            <h3 className="group-title">{titles[status]}</h3>
            {list(items)}
          </div>
        ),
      )}
      {inactive.length > 0 && (
        <div className="plan-group">
          <button
            type="button"
            className="button button--ghost group-toggle"
            aria-expanded={showInactive}
            aria-controls={inactiveId}
            onClick={() => setShowInactive((open) => !open)}
          >
            <Icon name={showInactive ? 'expand_less' : 'expand_more'} size={18} />
            {t.healthInactiveToggle(inactive.length)}
          </button>
          <div id={inactiveId} hidden={!showInactive}>
            {showInactive && list(inactive)}
          </div>
        </div>
      )}
      {doing && <DoneDialog item={{ planId: doing.id, petName: pet.name }} onClose={() => setDoing(null)} />}
    </div>
  );
}

/** A plan: its kind, title, when it is due (or that it is finished or paused), how often, when last done, "Done". */
function PlanRow({ pet, plan, onDone }: { pet: Pet; plan: CarePlan; onDone: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const { permissions } = useHousehold();
  const titleId = useId();
  const facts = [
    intervalLabel(t, plan.intervalValue, plan.intervalUnit),
    plan.lastDoneOn ? t.planLastDone(i18n.date(plan.lastDoneOn)) : null,
  ].filter(Boolean);
  return (
    <li className="row row--top">
      <span className="kind-icon">
        <Icon name={CARE_KIND_ICONS[plan.kind]} />
      </span>
      <div className="row-main">
        {permissions.canEdit ? (
          <Link to={`/pets/${pet.id}/plans/${plan.id}`} className="row-title row-link" id={titleId}>
            {plan.title}
          </Link>
        ) : (
          <span className="row-title" id={titleId}>
            {plan.title}
          </span>
        )}
        {plan.status === 'Inactive' ? (
          <span className="row-sub">{planStatusLabel(t, plan)}</span>
        ) : (
          <DueLine status={plan.status} daysLeft={plan.daysLeft} dueOn={plan.nextDueOn} />
        )}
        <span className="row-sub">{facts.join(' · ')}</span>
      </div>
      {/* Finished and paused plans can't be marked done: the form turns them on again. */}
      {plan.active && (
        <div className="row-actions">
          <button
            type="button"
            className="check-button"
            aria-label={t.planDone}
            title={t.planDone}
            aria-describedby={titleId}
            onClick={onDone}
          >
            <Icon name="check" />
          </button>
        </div>
      )}
    </li>
  );
}

function History({ pet, records }: { pet: Pet; records: CareRecord[] }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const [filter, setFilter] = useState<CareKind | 'all'>('all');

  if (records.length === 0) {
    if (!permissions.canEdit) return <p className="muted">{t.healthHistoryEmptyHelper}</p>;
    return (
      <div className="empty-section">
        <p className="muted">{t.healthHistoryEmpty}</p>
        <FirstRecords pet={pet} />
      </div>
    );
  }
  // Choices only for the kinds the history has, in the usual order. A filter whose last record went falls back to all.
  const kinds = CARE_KINDS.filter((kind) => records.some((record) => record.kind === kind));
  const chosen = filter !== 'all' && kinds.includes(filter) ? filter : 'all';
  const shown = chosen === 'all' ? records : records.filter((record) => record.kind === chosen);
  return (
    <div className="history">
      {kinds.length > 1 && (
        <ChoiceGroup
          label={t.healthFilterLabel}
          labelHidden
          value={chosen}
          options={[
            { value: 'all' as const, label: t.healthFilterAll },
            ...kinds.map((kind) => ({ value: kind, label: t.careKind[kind] })),
          ]}
          onChange={setFilter}
        />
      )}
      <ul className="card card--list rows">
        {shown.map((record) => (
          <RecordRow key={record.id} pet={pet} record={record} />
        ))}
      </ul>
    </div>
  );
}

/** A record: its kind, title, the date with the product, and how many photos and files it has. */
function RecordRow({ pet, record }: { pet: Pet; record: CareRecord }) {
  const i18n = useI18n();
  const { t } = i18n;
  const files = record.files.length;
  return (
    <li className="row">
      <span className="kind-icon">
        <Icon name={CARE_KIND_ICONS[record.kind]} />
      </span>
      <div className="row-main">
        <Link to={`/pets/${pet.id}/records/${record.id}`} className="row-title row-link">
          {record.title}
        </Link>
        <span className="row-sub">{[recordDateLabel(i18n, record), record.product].filter(Boolean).join(' · ')}</span>
      </div>
      {files > 0 && (
        <span className="row-meta" title={t.recordFileCount(files)}>
          <Icon name="photo" size={18} />
          <span className="visually-hidden">{t.recordFileCount(files)}</span>
        </span>
      )}
      <Icon name="chevron_right" className="row-arrow" />
    </li>
  );
}

/**
 * No records yet: the ways to fill the history, as cards. With AI on the server, from photos of the paper passport, of
 * a vet's document or from a note in words; and always as a table from the passport, or one by one by hand.
 */
function FirstRecords({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const ai = useAiStatus().data?.configured ?? false;
  return (
    <ActionList grid>
      {ai && (
        <>
          <ActionCard
            compact
            icon="document_scanner"
            title={t.scanCardTitle}
            hint={t.homeQuickScanHint}
            to={`/pets/${pet.id}/scan?from=health`}
          />
          <ActionCard
            compact
            icon="description"
            title={t.scanVetDocument}
            hint={t.homeQuickScanHint}
            to={`/pets/${pet.id}/scan?source=document&from=health`}
          />
          <ActionCard
            compact
            icon="edit_note"
            title={t.noteTitle}
            hint={t.homeQuickNoteHint}
            to={`/pets/${pet.id}/note?from=health`}
          />
        </>
      )}
      <ActionCard
        compact
        icon="playlist_add"
        title={t.bulkLink}
        hint={t.healthHistoryBulkHint}
        to={`/pets/${pet.id}/records/import`}
      />
      <ActionCard
        compact
        icon="add"
        title={t.healthHistoryAdd}
        hint={t.healthHistoryAddHint}
        to={`/pets/${pet.id}/records/new`}
      />
    </ActionList>
  );
}
