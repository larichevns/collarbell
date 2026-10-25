// Planned visits on Today: the past ones first, waiting for "The visit took place", then the coming ones. "All visits"
// opens the list of visits; "Add a visit" is for everyone but helpers. Home shows the next visit with VisitRow too.
import { useState } from 'react';
import { Link } from 'react-router';
import type { Today, TodayVisit } from '../../api/types';
import { Icon } from '../../components/Icon';
import { VISIT_TYPE_ICONS } from '../../components/kindIcons';
import { PetAvatar } from '../../components/PetAvatar';
import { Section, StatusTag } from '../../components/ui';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { visitWhen } from '../../lib/labels';
import { VisitDoneDialog } from '../visits/VisitDoneDialog';

export function VisitsSection({ today }: { today: Today }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const [marking, setMarking] = useState<TodayVisit | null>(null);
  return (
    <Section
      title={t.todayVisitsTitle}
      action={
        <>
          <Link to="/visits" className="button button--secondary">
            <Icon name="event" size={18} />
            {t.todayVisitsAll}
          </Link>
          {permissions.canEdit && (
            <Link to="/visits/new" className="button button--secondary">
              <Icon name="add" size={18} />
              {t.visitAdd}
            </Link>
          )}
        </>
      }
    >
      {today.appointments.length === 0 ? (
        <p className="muted">{t.todayVisitsEmpty}</p>
      ) : (
        <ul className="card card--list rows">
          {today.appointments.map((visit) => (
            <VisitRow key={visit.id} visit={visit} today={today.date} onTookPlace={() => setMarking(visit)} />
          ))}
        </ul>
      )}
      {marking && (
        <VisitDoneDialog
          visit={{ id: marking.id, type: marking.type, petIds: marking.pets.map((pet) => pet.id) }}
          onClose={() => setMarking(null)}
        />
      )}
    </Section>
  );
}

/** A planned visit: its kind, title, when (a past one waiting for "The visit took place"), where and its pets. */
export function VisitRow({ visit, today, onTookPlace }: { visit: TodayVisit; today: string; onTookPlace: () => void }) {
  const i18n = useI18n();
  const { t } = i18n;
  const past = visit.daysAway < 0;
  const when = visitWhen(i18n, visit.date, visit.time, today);
  return (
    <li className="row">
      <span className={`type-icon${past ? ' type-icon--warning' : ''}`}>
        <Icon name={VISIT_TYPE_ICONS[visit.type]} />
      </span>
      <div className="row-main">
        <Link to={`/visits/${visit.id}`} className="row-title row-link">
          {visit.title}
        </Link>
        {past ? (
          <StatusTag tone="warning" icon="event">
            {t.todayVisitHowWasIt(when)}
          </StatusTag>
        ) : (
          <span className="row-sub">{when}</span>
        )}
        {visit.location && <span className="row-sub">{visit.location}</span>}
      </div>
      <div className="row-actions">
        <span className="avatars">
          {visit.pets.slice(0, 3).map((pet) => (
            <PetAvatar key={pet.id} name={pet.name} photo={pet.photo} size="sm" />
          ))}
        </span>
        {past && (
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
      </div>
    </li>
  );
}
