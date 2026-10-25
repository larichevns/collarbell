// Today's feedings by time of day (the phone app's TodayFeedingSection). Each pet has "Fed" and "Skip"; "All fed"
// marks every pet still waiting at that time. A mark shows when it was made and by whom, and pressing it offers to take
// it back (helpers only their own). Two people can't mark the same feeding: the second learns who was first (409).
// The keyboard's focus stays in the row: from "Fed" to the spinner to the mark (or back).
//
// Home shows the next feeding with it too (`only`: that one time of the day, headed "Feeding at 8:00"), so marking
// works the same there, conflicts included.
import { useQueryClient } from '@tanstack/react-query';
import { useId, useLayoutEffect, useRef, useState, type MutableRefObject } from 'react';
import { ApiError, data } from '../../api/client';
import { errorMessage, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import type { FeedingMark, Today, TodayFeeding } from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import { Icon } from '../../components/Icon';
import { PetAvatar } from '../../components/PetAvatar';
import { useToast } from '../../components/Toasts';
import { Section, Spinner } from '../../components/ui';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { feedingSlots } from '../../lib/feeding';
import { feedingWhat } from '../../lib/labels';

/** A feeding is a pet's schedule at one time of the day. */
const keyOf = (item: TodayFeeding) => `${item.routineId}@${item.time}`;

/** The mark someone else made first, which a 409 brings. */
function takenBy(error: unknown): FeedingMark | null {
  if (!(error instanceof ApiError) || error.status !== 409) return null;
  const body = error.body as Partial<FeedingMark> | undefined;
  return body && typeof body.id === 'string' && typeof body.doneAt === 'string' ? (body as FeedingMark) : null;
}

export function FeedingSection({ today, only }: { today: Today; only?: string }) {
  const i18n = useI18n();
  const { t } = i18n;
  const api = useApi();
  const { current } = useHousehold();
  const queryClient = useQueryClient();
  const toast = useToast();
  const [busy, setBusy] = useState<ReadonlySet<string>>(new Set());
  const [skipping, setSkipping] = useState<TodayFeeding | null>(null);
  const [undoing, setUndoing] = useState<{ item: TodayFeeding; mark: FeedingMark } | null>(null);
  /** The row whose control the focus goes to once its work is done: the one acted on. */
  const focusAfter = useRef<string | null>(null);

  const household = current.id;
  const at = (mark: FeedingMark) => i18n.momentTime(mark.doneAt, current.timeZone);

  /** The mark goes into the copy on screen at once; the reload that follows brings the server's word. */
  function show(item: TodayFeeding, mark: FeedingMark | null) {
    const same = keyOf(item);
    queryClient.setQueryData<Today>(
      keys.today(household, today.date),
      (old) =>
        old && {
          ...old,
          feedings: old.feedings.map((feeding) => (keyOf(feeding) === same ? { ...feeding, mark } : feeding)),
        },
    );
  }

  function setWorking(items: TodayFeeding[], working: boolean) {
    setBusy((old) => {
      const next = new Set(old);
      for (const item of items) {
        if (working) next.add(keyOf(item));
        else next.delete(keyOf(item));
      }
      return next;
    });
  }

  /** Marks the feedings one after another; the ones someone else marked first show that mark, and who it was. */
  async function mark(items: TodayFeeding[], status: 'Done' | 'Skipped') {
    if (items[0]) focusAfter.current = keyOf(items[0]);
    setWorking(items, true);
    let first: FeedingMark | null = null;
    let failure: unknown = null;
    for (const item of items) {
      try {
        const made = await data(
          api.POST('/api/v1/routines/{id}/completions', {
            params: { path: { id: item.routineId } },
            body: { date: today.date, time: item.time, status },
          }),
        );
        show(item, made);
      } catch (error) {
        const taken = takenBy(error);
        if (taken) {
          first ??= taken;
          show(item, taken);
          continue;
        }
        failure = error;
        // No answer: the next pets would only wait as long.
        if (error instanceof ApiError && error.status === 0) break;
      }
    }
    setWorking(items, false);
    if (first) toast(t.feedingAlreadyMarked(first.byName ?? t.feedingSomeoneElse, at(first)));
    else if (failure) toast(errorMessage(t, failure));
    void queryClient.invalidateQueries({ queryKey: keys.todayAll(household) });
  }

  async function undo(item: TodayFeeding, mark: FeedingMark) {
    focusAfter.current = keyOf(item);
    setWorking([item], true);
    try {
      await api.DELETE('/api/v1/routines/{id}/completions/{completionId}', {
        params: { path: { id: item.routineId, completionId: mark.id } },
      });
      show(item, null);
    } catch (error) {
      // Taken back already, on another device: that is what was wanted.
      if (isNotFound(error)) show(item, null);
      else toast(errorMessage(t, error));
    } finally {
      setWorking([item], false);
      void queryClient.invalidateQueries({ queryKey: keys.todayAll(household) });
    }
  }

  // By time of day, earliest first; within a time, the server's order. Home: only the time it asks for.
  const slots = [...feedingSlots(today.feedings)].filter(([time]) => only === undefined || time === only);

  // Home: the time on screen moved on (its last pet was just marked) while the focus was in it. The control that had it
  // is gone, so the focus goes to the next time's first "Fed" (or its heading) rather than to the start of the page.
  // The focus that left the cards for something else (a blur to elsewhere) is left alone.
  const cardsRef = useRef<HTMLDivElement>(null);
  const focusedIn = useRef<HTMLElement | null>(null);
  const shownTime = useRef(only);
  useLayoutEffect(() => {
    if (only === undefined || shownTime.current === only) return;
    shownTime.current = only;
    const had = focusedIn.current;
    const lost = !document.activeElement || document.activeElement === document.body;
    if (!had || had.isConnected || !lost) return;
    focusAfter.current = null;
    const cards = cardsRef.current;
    const fed = cards?.querySelector<HTMLElement>('.row-actions .button--tonal');
    (fed ?? cards?.querySelector<HTMLElement>('h3'))?.focus();
  }, [only]);

  const cards = (
    <div
      className="slots"
      ref={cardsRef}
      onFocus={(event) => {
        focusedIn.current = event.target;
      }}
      onBlur={(event) => {
        // Gone elsewhere: nothing to bring back. Some browsers blur a control as it is removed, too: that one counts
        // as lost, so it is let go only if still on the page a moment later.
        if (event.currentTarget.contains(event.relatedTarget as Node | null)) return;
        const left = event.target;
        window.setTimeout(() => {
          if (left.isConnected && focusedIn.current === left) focusedIn.current = null;
        });
      }}
    >
      {slots.map(([time, items]) => {
        const open = items.filter((item) => !item.mark && !busy.has(keyOf(item)));
        return (
          <div key={time} className="card card--list slot">
            <div className="slot-head">
              <h3
                className={only === undefined ? 'slot-time' : 'slot-title'}
                tabIndex={only === undefined ? undefined : -1}
              >
                {only === undefined ? i18n.time(time) : t.homeNextFeeding(i18n.time(time))}
              </h3>
              {/* Two or more pets still to feed at this time. */}
              {open.length > 1 && (
                <button type="button" className="button button--secondary" onClick={() => void mark(open, 'Done')}>
                  <Icon name="done_all" size={18} />
                  {t.feedingAll}
                </button>
              )}
            </div>
            <ul className="rows">
              {items.map((item) => (
                <FeedingRow
                  key={keyOf(item)}
                  item={item}
                  focusAfter={focusAfter}
                  busy={busy.has(keyOf(item))}
                  markedAt={item.mark ? at(item.mark) : null}
                  onFed={() => void mark([item], 'Done')}
                  onSkip={() => setSkipping(item)}
                  onUndo={(mark) => setUndoing({ item, mark })}
                />
              ))}
            </ul>
          </div>
        );
      })}
    </div>
  );
  const dialogs = (
    <>
      {skipping && (
        <ConfirmDialog
          title={t.feedingSkipTitle(skipping.petName)}
          body={t.feedingSkipBody(i18n.time(skipping.time))}
          confirmLabel={t.feedingSkip}
          onConfirm={() => {
            setSkipping(null);
            void mark([skipping], 'Skipped');
          }}
          onCancel={() => setSkipping(null)}
        />
      )}
      {undoing && (
        <ConfirmDialog
          title={t.feedingUndoTitle(undoing.item.petName)}
          body={t.feedingUndoBody}
          confirmLabel={t.feedingUndo}
          onConfirm={() => {
            setUndoing(null);
            void undo(undoing.item, undoing.mark);
          }}
          onCancel={() => setUndoing(null)}
        />
      )}
    </>
  );

  // Home's "Right now" has a heading of its own; the slot's says what it is.
  if (only !== undefined) {
    return (
      <div className="home-feeding">
        {cards}
        {dialogs}
      </div>
    );
  }
  return (
    <Section title={t.todayFeedingTitle}>
      {cards}
      {dialogs}
    </Section>
  );
}

function FeedingRow({
  item,
  focusAfter,
  busy,
  markedAt,
  onFed,
  onSkip,
  onUndo,
}: {
  item: TodayFeeding;
  /** The row the focus goes back to once its work is done. */
  focusAfter: MutableRefObject<string | null>;
  busy: boolean;
  markedAt: string | null;
  onFed: () => void;
  onSkip: () => void;
  onUndo: (mark: FeedingMark) => void;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const { permissions } = useHousehold();
  const nameId = useId();
  const { mark } = item;
  const actionsRef = useRef<HTMLDivElement>(null);
  // Done (or failed): the focus goes to what the row has now, the mark or "Fed".
  useLayoutEffect(() => {
    if (busy || focusAfter.current !== keyOf(item)) return;
    const control = actionsRef.current?.querySelector<HTMLElement>('button');
    if (!control) return;
    focusAfter.current = null;
    control.focus();
  });
  const what = feedingWhat(i18n, item.food, item.amount, item.unit);
  const by = mark && !mark.byMe ? t.feedingMarkedBy(mark.byName ?? t.feedingSomeoneElse) : null;

  let actions;
  if (busy) {
    actions = <Spinner />;
  } else if (!mark || !markedAt) {
    actions = (
      <>
        <button type="button" className="button button--tonal" aria-describedby={nameId} onClick={onFed}>
          {t.feedingFed}
        </button>
        <button type="button" className="button button--ghost" aria-describedby={nameId} onClick={onSkip}>
          {t.feedingSkip}
        </button>
      </>
    );
  } else {
    const skipped = mark.status === 'Skipped';
    const label = skipped ? t.feedingSkippedAt(markedAt) : t.feedingFedAt(markedAt);
    // The tick and the time are what the eye needs; a screen reader hears the whole phrase.
    const look = (
      <>
        <Icon
          name={skipped ? 'do_not_disturb_on' : 'check_circle'}
          className={`mark-icon mark-icon--${skipped ? 'skipped' : 'done'}`}
        />
        <span aria-hidden="true">{skipped ? label : markedAt}</span>
      </>
    );
    // Helpers take back only their own marks.
    actions = permissions.canTakeBack(mark.byMe) ? (
      <button
        type="button"
        className="mark mark--button"
        aria-label={`${label}. ${t.feedingUndo}`}
        aria-describedby={nameId}
        onClick={() => onUndo(mark)}
      >
        {look}
      </button>
    ) : (
      <span className="mark">
        {look}
        <span className="visually-hidden">{label}</span>
      </span>
    );
  }

  return (
    <li className="row">
      <PetAvatar name={item.petName} photo={item.petPhoto} size="sm" />
      <div className="row-main">
        <span className="row-title" id={nameId}>
          {item.petName}
        </span>
        {what && <span className="row-sub">{what}</span>}
        {by && <span className="row-sub">{by}</span>}
      </div>
      <div className="row-actions" ref={actionsRef}>
        {actions}
      </div>
    </li>
  );
}
