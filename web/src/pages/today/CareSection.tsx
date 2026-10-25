// Care that is due, by group: overdue, due soon (within 14 days) and later (the rest of the 30 days Today looks
// ahead). "Done" opens the dialog that records it; the pet's name opens the pet's page.
import { useId, useRef, useState } from 'react';
import { useKeepFocus } from '../../components/useKeepFocus';
import { Link } from 'react-router';
import type { TodayCare } from '../../api/types';
import { DueLine } from '../../components/DueLine';
import { Icon } from '../../components/Icon';
import { PetAvatar } from '../../components/PetAvatar';
import { Section } from '../../components/ui';
import { useI18n } from '../../i18n/i18n';
import { DoneDialog } from './DoneDialog';

export function CareSection({ items }: { items: TodayCare[] }) {
  const { t } = useI18n();
  const [doing, setDoing] = useState<TodayCare | null>(null);
  // Done: the plan leaves its group, and the focus goes to the next one.
  const container = useRef<HTMLDivElement>(null);
  useKeepFocus(container);
  const groups = [
    { title: t.careStatusOverdue, items: items.filter((item) => item.status === 'Overdue') },
    { title: t.careStatusDueSoon, items: items.filter((item) => item.status === 'DueSoon') },
    { title: t.todayGroupLater, items: items.filter((item) => item.status !== 'Overdue' && item.status !== 'DueSoon') },
  ].filter((group) => group.items.length > 0);

  return (
    <div className="today-care" ref={container}>
      {groups.map((group) => (
        <Section key={group.title} title={group.title}>
          <ul className="card card--list rows">
            {group.items.map((item) => (
              <CareRow key={item.planId} item={item} onDone={() => setDoing(item)} />
            ))}
          </ul>
        </Section>
      ))}
      {doing && <DoneDialog item={doing} onClose={() => setDoing(null)} />}
    </div>
  );
}

function CareRow({ item, onDone }: { item: TodayCare; onDone: () => void }) {
  const { t } = useI18n();
  const titleId = useId();
  const kind = t.careKind[item.kind];
  return (
    <li className="row">
      <PetAvatar name={item.petName} photo={item.petPhoto} />
      <div className="row-main">
        <span className="row-title" id={titleId}>
          {item.title}
        </span>
        <span className="row-sub">
          <Link to={`/pets/${item.petId}`}>{item.petName}</Link>
          {/* The kind only when the title doesn't say it already. */}
          {kind !== item.title && ` · ${kind}`}
        </span>
        <DueLine status={item.status} daysLeft={item.daysLeft} dueOn={item.nextDueOn} />
      </div>
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
    </li>
  );
}
