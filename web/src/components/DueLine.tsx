import type { CareStatus } from '../api/types';
import { useI18n } from '../i18n/i18n';
import { dueLabel } from '../lib/labels';
import { Icon } from './Icon';
import type { IconName } from './icons';

const LOOK: Record<CareStatus, { icon: IconName; tone: 'danger' | 'warning' | 'muted' }> = {
  Overdue: { icon: 'error', tone: 'danger' },
  DueSoon: { icon: 'schedule', tone: 'warning' },
  Upcoming: { icon: 'event', tone: 'muted' },
  Inactive: { icon: 'pause_circle', tone: 'muted' },
};

/**
 * When something is due: overdue in a red tag, due soon in a yellow one (the status tags of ui.tsx), the rest calm
 * muted text. The colour is never alone: the icon and the words say the same, e.g. "3 days overdue · Sep 28, 2026".
 */
export function DueLine({ status, daysLeft, dueOn }: { status: CareStatus; daysLeft: number; dueOn: string }) {
  const i18n = useI18n();
  const { icon, tone } = LOOK[status];
  return (
    <span className={tone === 'muted' ? 'due due--muted' : `due tag tag--${tone}`}>
      <Icon name={icon} size={16} />
      <span>
        {dueLabel(i18n.t, daysLeft)} · <span className="nowrap">{i18n.date(dueOn)}</span>
      </span>
    </span>
  );
}
