import { useEffect, useState } from 'react';
import { todayIn } from '../lib/dates';
import { useHousehold } from './household';

/**
 * Today in the household's time zone ("2026-10-07"), the date feedings and visits are counted in. Checked again every
 * half minute and when the window comes back, so a page left open over midnight moves on to the new day: yesterday's
 * feedings must not be marked as today's.
 */
export function useHouseholdDate(): string {
  const { current } = useHousehold();
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const tick = () => setNow(new Date());
    const timer = window.setInterval(tick, 30_000);
    window.addEventListener('focus', tick);
    return () => {
      window.clearInterval(timer);
      window.removeEventListener('focus', tick);
    };
  }, []);
  return todayIn(current.timeZone, now);
}
