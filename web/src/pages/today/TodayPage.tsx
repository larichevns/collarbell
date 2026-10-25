// Today: what the household has to do today, for all its active pets (GET /today for the household's date). Feedings
// by time with "Fed", "Skip" and "All fed"; visits, the past ones waiting for "The visit took place"; what to buy, with
// "Bought"; care that is overdue, due soon or due later in the next 30 days, with "Done". Read again every 30 seconds
// and when the window comes back to the front: someone else may have fed the cat meanwhile; a reload that fails keeps
// the day on screen under the reason. On a wide screen the
// day's routine (feeding, visits) is on the left, what needs doing about it (buying, care) on the right.
import { ApiError } from '../../api/client';
import { useToday } from '../../api/queries';
import type { Today } from '../../api/types';
import { ErrorNotice, Loading, PageHead } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { householdName } from '../../lib/labels';
import { CareSection } from './CareSection';
import { FeedingSection } from './FeedingSection';
import { TodayFirstSteps } from './FirstSteps';
import { ShoppingSection } from './ShoppingSection';
import { VisitsSection } from './VisitsSection';

export function TodayPage() {
  const { t } = useI18n();
  const date = useHouseholdDate();
  const today = useToday(date);
  const { data, error } = today;
  const caption = useDayCaption(data?.date ?? date);

  let content;
  if (!data) {
    content = error ? <ErrorNotice error={error} onRetry={() => void today.refetch()} /> : <Loading />;
  } else if (isEmptyDay(data)) {
    content = <TodayFirstSteps />;
  } else {
    content = (
      <div className="today">
        <div className="today-column">
          {data.feedings.length > 0 && <FeedingSection today={data} />}
          <VisitsSection today={data} />
        </div>
        <div className="today-column">
          {data.shopping.length > 0 && <ShoppingSection today={data} />}
          <CareSection items={data.care} />
        </div>
      </div>
    );
  }
  // A reload that failed keeps the day on screen (and what is open on it, a "Done" dialog), with the reason above it:
  // something just marked elsewhere may look as before. No answer at all: the offline strip says so already.
  const stale = data && error && !(error instanceof ApiError && error.status === 0);

  return (
    <>
      <PageHead title={t.todayTitle} caption={caption} />
      {stale && <ErrorNotice error={error} onRetry={() => void today.refetch()} />}
      {content}
    </>
  );
}

/**
 * The line above Today's and Home's title: the day ("Wednesday, October 7" starts a line, so it is capitalised) and,
 * for someone in several groups, which one this is.
 */
export function useDayCaption(date: string): string {
  const i18n = useI18n();
  const { current, households } = useHousehold();
  const day = i18n.date(date, 'weekday');
  return [
    day.charAt(0).toUpperCase() + day.slice(1),
    households.length > 1 ? householdName(i18n.t, current.name, current.role) : null,
  ]
    .filter(Boolean)
    .join(' · ');
}

/** Nothing on the day at all: no feedings, visits, care or shopping (nothing set up yet). */
export function isEmptyDay(today: Today): boolean {
  return !today.feedings.length && !today.appointments.length && !today.care.length && !today.shopping.length;
}
