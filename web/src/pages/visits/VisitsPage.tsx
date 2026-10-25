// Visits: the planned ones (soonest first), then the past and cancelled ones (newest first), as the server orders them.
// A planned visit whose day has come offers "The visit took place" right in the list. "Add a visit" for everyone but
// helpers, who see the visits and say how they went; with no visits yet it is under the empty text.
import { useState } from 'react';
import { Link } from 'react-router';
import { usePets, useVisits } from '../../api/queries';
import type { Pet, Visit } from '../../api/types';
import { Icon } from '../../components/Icon';
import { VISIT_TYPE_ICONS } from '../../components/kindIcons';
import { EmptyState, ErrorNotice, Loading, PageHead, Section } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { visitWhen } from '../../lib/labels';
import { VisitDoneDialog } from './VisitDoneDialog';

export function VisitsPage() {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const today = useHouseholdDate();
  const visits = useVisits();
  const pets = usePets().data ?? [];
  const [marking, setMarking] = useState<Visit | null>(null);

  let content;
  if (visits.error && !visits.data) {
    content = <ErrorNotice error={visits.error} onRetry={() => void visits.refetch()} />;
  } else if (!visits.data) {
    content = <Loading />;
  } else if (visits.data.length === 0) {
    content = (
      <EmptyState
        icon="event"
        title={t.visitsEmptyTitle}
        actions={
          permissions.canEdit && (
            <Link to="/visits/new" className="button button--primary">
              <Icon name="add" />
              {t.visitAdd}
            </Link>
          )
        }
      >
        {permissions.canEdit ? t.visitsEmptyBody : t.visitsEmptyBodyHelper}
      </EmptyState>
    );
  } else {
    const planned = visits.data.filter((visit) => visit.status === 'Planned');
    const past = visits.data.filter((visit) => visit.status !== 'Planned');
    const list = (items: Visit[]) => (
      <ul className="card card--list rows">
        {items.map((visit) => (
          <VisitRow key={visit.id} visit={visit} pets={pets} today={today} onTookPlace={() => setMarking(visit)} />
        ))}
      </ul>
    );
    content = (
      <>
        {planned.length > 0 && <Section title={t.visitsPlanned}>{list(planned)}</Section>}
        {past.length > 0 && <Section title={t.visitsPast}>{list(past)}</Section>}
      </>
    );
  }

  return (
    <>
      <PageHead
        title={t.visitsTitle}
        actions={
          // Empty (or still loading): the button is under the empty text instead.
          permissions.canEdit &&
          (visits.data ? visits.data.length > 0 : !!visits.error) && (
            <Link to="/visits/new" className="button button--primary">
              <Icon name="add" />
              {t.visitAdd}
            </Link>
          )
        }
      />
      {content}
      {marking && <VisitDoneDialog visit={marking} onClose={() => setMarking(null)} />}
    </>
  );
}

function VisitRow({
  visit,
  pets,
  today,
  onTookPlace,
}: {
  visit: Visit;
  pets: Pet[];
  today: string;
  onTookPlace: () => void;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const planned = visit.status === 'Planned';
  const names = visit.petIds.map((id) => pets.find((pet) => pet.id === id)?.name).filter(Boolean);
  return (
    <li className="row">
      <span className={`type-icon${planned ? '' : ' type-icon--muted'}`}>
        <Icon name={VISIT_TYPE_ICONS[visit.type]} />
      </span>
      <div className="row-main">
        <Link to={`/visits/${visit.id}`} className="row-title row-link">
          {visit.title}
        </Link>
        <span className="row-sub">
          {[visitWhen(i18n, visit.date, visit.time, today), planned ? null : t.visitStatus[visit.status]]
            .filter(Boolean)
            .join(' · ')}
        </span>
        {names.length > 0 && <span className="row-sub">{names.join(', ')}</span>}
      </div>
      <div className="row-actions">
        {planned && visit.date <= today && (
          <button
            type="button"
            className="button button--tonal"
            // Which visit, for those who hear the button alone.
            aria-label={t.visitDoneFor(visit.title)}
            onClick={onTookPlace}
          >
            {t.visitDone}
          </button>
        )}
        <Icon name="chevron_right" className="row-arrow" />
      </div>
    </li>
  );
}
