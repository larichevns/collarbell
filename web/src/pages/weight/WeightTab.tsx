// The Weight tab (the phone app's weight_tab.dart): the latest weight, large, with its change since the one before and
// its body condition score; the weight over time on a chart (the periods 3 months, 1 year and all time to choose from
// once the log is longer than three months; a longer log opens on its last year when that year has two weights); and
// every weight, newest first. The household weighs the pet; the weights a vet noted at check-ups join in from the care
// records and open their record. Helpers see the weights; adding and changing them is for the others.
import { useRef, useState } from 'react';
import { Link } from 'react-router';
import { useWeights } from '../../api/queries';
import type { Pet, Weight } from '../../api/types';
import { ChoiceGroup } from '../../components/fields';
import { Icon } from '../../components/Icon';
import { WEIGHT_SOURCE_ICONS } from '../../components/kindIcons';
import { WeightChart } from '../../components/WeightChart';
import { EmptyState, Loaded, Section } from '../../components/ui';
import { useKeepFocus } from '../../components/useKeepFocus';
import { useHouseholdDate } from '../../household/date';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { weightChangeLabel, weightNumberLabel, weightValueLabel } from '../../lib/labels';
import { bcsIdeal, changeAt, defaultPeriod, weightPeriods, weightsIn, type WeightPeriod } from '../../lib/weight';
import { WeightDialog } from './WeightDialog';

export function WeightTab({ pet }: { pet: Pet }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  const weights = useWeights(pet.id);
  const today = useHouseholdDate();
  // null: a new weighing; a weighing: change it.
  const [editing, setEditing] = useState<Weight | null | false>(false);
  // A weighing deleted: the focus goes to the one now in its place.
  const history = useRef<HTMLUListElement>(null);
  useKeepFocus(history);

  const add = permissions.canEdit && (
    <button type="button" className="button button--secondary" onClick={() => setEditing(null)}>
      <Icon name="add" size={18} />
      {t.commonAdd}
    </button>
  );

  return (
    <>
      <Loaded query={weights}>
        {(log) =>
          log.length === 0 ? (
            <EmptyState
              icon="monitor_weight"
              title={t.weightEmptyTitle}
              actions={
                permissions.canEdit && (
                  <button type="button" className="button button--primary" onClick={() => setEditing(null)}>
                    <Icon name="add" />
                    {t.weightAddFirst}
                  </button>
                )
              }
            >
              {permissions.canEdit ? t.weightEmptyBody : t.weightEmptyBodyHelper}
            </EmptyState>
          ) : (
            <div className="tab-sections">
              <Section title={t.weightLatestTitle} action={add}>
                <Latest log={log} today={today} />
              </Section>
              <Section title={t.weightTrendTitle}>
                <Trend log={log} today={today} />
              </Section>
              <Section title={t.weightHistoryTitle}>
                <ul className="card card--list rows" ref={history}>
                  {log.map((entry, index) => (
                    <WeightRow
                      key={`${entry.source}-${entry.id}`}
                      pet={pet}
                      entry={entry}
                      change={changeAt(log, index)}
                      onEdit={permissions.canEdit ? () => setEditing(entry) : null}
                    />
                  ))}
                </ul>
              </Section>
            </div>
          )
        }
      </Loaded>
      {editing !== false && <WeightDialog pet={pet} weighing={editing} onClose={() => setEditing(false)} />}
    </>
  );
}

/** "+0.2 kg since Sep 12", or "No change since Sep 12": dates of this year without the year. */
function changeSince(i18n: ReturnType<typeof useI18n>, change: number, since: string, today: string): string {
  const date = i18n.date(since, since.slice(0, 4) === today.slice(0, 4) ? 'dayMonth' : 'medium');
  return change === 0
    ? i18n.t.weightNoChangeSince(date)
    : i18n.t.weightChangeSince(weightChangeLabel(i18n, change), date);
}

/** The latest weight, large, with its date, the change since the weight before it, and its body condition score. */
function Latest({ log, today }: { log: Weight[]; today: string }) {
  const i18n = useI18n();
  const { t } = i18n;
  const latest = log[0]!;
  const change = changeAt(log, 0);
  const before = log[1];
  return (
    <div className="card latest-weight">
      <p className="latest-weight-value">
        {/* The unit smaller than the number: the number is what is read. */}
        <span className="latest-weight-number">{weightNumberLabel(i18n, latest.weightKg)}</span>{' '}
        <span className="latest-weight-unit">{t.weightUnitKg}</span>
      </p>
      <p className="muted small">
        {[i18n.date(latest.measuredOn), latest.source === 'CareRecord' ? t.weightSource.CareRecord : null]
          .filter(Boolean)
          .join(' · ')}
      </p>
      {change !== null && before && (
        <p className="latest-weight-change">
          {/* Up or down isn't good or bad by itself (a kitten should gain): the arrow is grey. */}
          <Icon name={change > 0 ? 'trending_up' : change < 0 ? 'trending_down' : 'trending_flat'} />
          {changeSince(i18n, change, before.measuredOn, today)}
        </p>
      )}
      {latest.bcs !== null && latest.bcsScale !== null && (
        <p>
          {[t.weightBodyCondition(latest.bcs, latest.bcsScale), t.weightBcsIdeal(bcsIdeal(latest.bcsScale))].join(
            ' · ',
          )}
        </p>
      )}
    </div>
  );
}

/** The chart of the chosen period, with the periods to choose from when the log is longer than three months. */
function Trend({ log, today }: { log: Weight[]; today: string }) {
  const { t } = useI18n();
  const [chosen, setChosen] = useState<WeightPeriod | null>(null);
  const periods = weightPeriods(log.at(-1)!.measuredOn, today);
  const period = chosen && periods.includes(chosen) ? chosen : defaultPeriod(periods, log, today);
  const shown = weightsIn(log, period, today);
  return (
    <div className="trend">
      {periods.length > 0 && (
        <ChoiceGroup
          label={t.weightPeriodLabel}
          labelHidden
          value={period}
          options={periods.map((each) => ({ value: each, label: t.weightPeriod[each] }))}
          onChange={setChosen}
        />
      )}
      {shown.length >= 2 ? (
        <div className="card">
          <WeightChart
            points={[...shown].reverse().map((entry) => ({
              measuredOn: entry.measuredOn,
              weightKg: entry.weightKg,
              vet: entry.source === 'CareRecord',
            }))}
            today={today}
          />
        </div>
      ) : (
        <p className="muted">{log.length < 2 ? t.weightChartNeedsTwo : t.weightChartTooFew}</p>
      )}
    </div>
  );
}

/**
 * A weight of the history: where it comes from, the weight, then the date, the change from the one before it and the
 * score, and the note (a vet's weight: its record's title). A weighing opens its dialog; a vet's weight its record.
 */
function WeightRow({
  pet,
  entry,
  change,
  onEdit,
}: {
  pet: Pet;
  entry: Weight;
  change: number | null;
  onEdit: (() => void) | null;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const value = weightValueLabel(i18n, entry.weightKg);
  const details = [
    i18n.date(entry.measuredOn),
    change !== null ? weightChangeLabel(i18n, change) : null,
    entry.bcs !== null && entry.bcsScale !== null ? t.weightBodyCondition(entry.bcs, entry.bcsScale) : null,
  ];
  const vet = entry.source === 'CareRecord';
  let title;
  if (vet) {
    title = (
      <Link to={`/pets/${pet.id}/records/${entry.id}?from=weight`} className="row-title row-link">
        {value}
      </Link>
    );
  } else if (onEdit) {
    title = (
      <button type="button" className="row-title row-link row-button" onClick={onEdit}>
        {value}
      </button>
    );
  } else {
    title = <span className="row-title">{value}</span>;
  }
  return (
    <li className="row">
      <span className="type-icon type-icon--muted" role="img" aria-label={t.weightSource[entry.source]}>
        <Icon name={WEIGHT_SOURCE_ICONS[entry.source]} />
      </span>
      <div className="row-main">
        {title}
        <span className="row-sub">{details.filter(Boolean).join(' · ')}</span>
        {entry.note?.trim() && <span className="row-sub weight-note">{entry.note}</span>}
      </div>
      {(vet || onEdit) && <Icon name="chevron_right" className="row-arrow" />}
    </li>
  );
}
