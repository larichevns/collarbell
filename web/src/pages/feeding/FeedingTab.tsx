// The Feeding tab (the phone app's feeding_tab.dart): the pet's feeding schedules, active ones first. Each says its
// times, its days (or "Every day"), whether it is paused, and what and how much is given. At each time a reminder
// comes and Today shows a "Fed" button. Those who change things add schedules and open one to change it; with none yet,
// "Add feeding" is the tab's main button, under the empty text.
import { Link } from 'react-router';
import { useRoutines } from '../../api/queries';
import type { Pet, Routine } from '../../api/types';
import { Icon } from '../../components/Icon';
import { Loaded, Section } from '../../components/ui';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { orderedTimes } from '../../lib/feeding';
import { feedingDaysLabel, feedingWhat } from '../../lib/labels';

export function FeedingTab({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const routines = useRoutines(pet.id);
  const add = `/pets/${pet.id}/feeding/new`;
  return (
    <Section
      title={t.feedingTitle}
      action={
        // Empty (or still loading): "Add feeding" is under the empty text instead.
        permissions.canEdit &&
        (routines.data ? routines.data.length > 0 : !!routines.error) && (
          <Link to={add} className="button button--secondary">
            <Icon name="add" size={18} />
            {t.commonAdd}
          </Link>
        )
      }
    >
      <Loaded query={routines}>
        {(value) =>
          value.length === 0 ? (
            permissions.canEdit ? (
              <div className="empty-section">
                <p className="muted">{t.feedingEmpty}</p>
                <Link to={add} className="button button--primary">
                  <Icon name="add" />
                  {t.todayAddFeeding}
                </Link>
              </div>
            ) : (
              <p className="muted">{t.feedingEmptyHelper}</p>
            )
          ) : (
            <ul className="card card--list rows">
              {value.map((routine) => (
                <ScheduleRow key={routine.id} pet={pet} routine={routine} />
              ))}
            </ul>
          )
        }
      </Loaded>
    </Section>
  );
}

/** A schedule: its times large, then its days and what is given. */
function ScheduleRow({ pet, routine }: { pet: Pet; routine: Routine }) {
  const i18n = useI18n();
  const { t } = i18n;
  const { permissions } = useHousehold();
  const times = orderedTimes(routine.times)
    .map((time) => i18n.time(time))
    .join(' · ');
  const what = feedingWhat(i18n, routine.food, routine.amount, routine.unit);
  const days = [feedingDaysLabel(i18n, routine.days), routine.active ? null : t.feedingPaused].filter(Boolean);
  return (
    <li className={`row row--top${routine.active ? '' : ' row--paused'}`}>
      <span className={`type-icon${routine.active ? '' : ' type-icon--muted'}`}>
        <Icon name="restaurant" />
      </span>
      <div className="row-main">
        {permissions.canEdit ? (
          <Link to={`/pets/${pet.id}/feeding/${routine.id}`} className="row-title row-link schedule-times">
            {times}
          </Link>
        ) : (
          <span className="row-title schedule-times">{times}</span>
        )}
        <span className="row-sub">{days.join(' · ')}</span>
        {what && <span className="row-sub">{what}</span>}
        {routine.notes && <span className="row-sub pre-line">{routine.notes}</span>}
      </div>
      {permissions.canEdit && <Icon name="chevron_right" className="row-arrow" />}
    </li>
  );
}
