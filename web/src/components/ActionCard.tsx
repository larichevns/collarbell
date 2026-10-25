// A call to action as a card (the phone app's CbActionCard), where several things can be started: an empty page's
// first steps, Home's quick actions, the onboarding. An icon in a mint circle, a title, a one-line "why" and a chevron;
// the whole card is one link (or one button), so the words are as easy to hit as the icon, with one focus ring.
//
// The rule it belongs to (docs/mvp-spec.md, "Главная, знакомство, кнопки"): the main action of a page or a section is
// a primary button; other calls to action are outlined (secondary) buttons, or these cards where several things can be
// started. A call to action is never bare text or a bare icon.
//
// `compact` is the small card of a grid (ActionList grid): the icon on top, no chevron. `primary` marks the one thing
// to do first: the card is mint and its circle the bright green, with a white icon.
import { useId, type ReactNode } from 'react';
import { Link, type To } from 'react-router';
import { Icon } from './Icon';
import type { IconName } from './icons';

interface ActionCardProps {
  icon: IconName;
  title: string;
  /** Why to do it, in a few words ("We'll remind you when to feed"). */
  hint?: string | null;
  /** Where it leads; or, without it, what a press does. */
  to?: To;
  onClick?: () => void;
  primary?: boolean;
  compact?: boolean;
}

export function ActionCard({ icon, title, hint, to, onClick, primary = false, compact = false }: ActionCardProps) {
  const id = useId();
  const className = `action-card${primary ? ' action-card--primary' : ''}${compact ? ' action-card--compact' : ''}`;
  // The title names the card; the hint describes it, so a screen reader says the title first and the "why" after.
  const content = (
    <>
      <span className="action-card-icon" aria-hidden="true">
        <Icon name={icon} />
      </span>
      <span className="action-card-text">
        <span className="action-card-title" id={`${id}-title`}>
          {title}
        </span>
        {hint && (
          <span className="action-card-hint" id={`${id}-hint`}>
            {hint}
          </span>
        )}
      </span>
      {!compact && <Icon name="chevron_right" className="action-card-arrow" />}
    </>
  );
  const named = { 'aria-labelledby': `${id}-title`, 'aria-describedby': hint ? `${id}-hint` : undefined };
  if (to !== undefined) {
    return (
      <Link to={to} className={className} {...named}>
        {content}
      </Link>
    );
  }
  return (
    <button type="button" className={className} onClick={onClick} {...named}>
      {content}
    </button>
  );
}

/**
 * Action cards one under another (`grid`: compact ones side by side, as many to a row as fit, each row as tall as its
 * tallest card, so their icons line up; one to a row on a phone's width).
 */
export function ActionList({ grid = false, children }: { grid?: boolean; children: ReactNode }) {
  return <div className={grid ? 'action-grid' : 'action-list'}>{children}</div>;
}
