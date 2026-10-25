// The визор: what a person did in the app over the last 7 days and what the server answered, newest first. Lines are
// grouped by day and by session (one launch of the app); requests show the answer's status (2xx green, 4xx yellow,
// 5xx red) and how long it took. Filters (запросы / экраны / действия / ошибки) are kept in the address (?show=),
// "Показать ещё" brings the next 200 lines. Opened from "Проблемы" with ?at=…, it starts 10 minutes after that moment
// and marks the line of the problem.
import { useEffect, useRef, useState } from 'react';
import { Link, useSearchParams } from 'react-router';
import { TIMELINE_LIMIT } from '../api/client';
import type { TimelineEvent } from '../api/types';
import { Badge, Chip, ErrorNotice, Icon, Loading, Notice, Spinner } from '../components/ui';
import {
  formatCount,
  formatDateTime,
  formatDayHeading,
  formatDurationMs,
  formatFull,
  formatMinutes,
  formatTime,
  formatTimeWithSeconds,
  shortenIds,
} from '../lib/format';
import { useNow } from '../lib/hooks';
import { statusTone, timelineKind } from '../lib/labels';
import {
  appendPage,
  beforeForAround,
  closestLine,
  countByFilter,
  formatFilters,
  groupTimeline,
  isShown,
  KIND_FILTERS,
  parseFilters,
  sessionSummary,
  type KindFilter,
  type SessionBlock,
} from '../lib/timeline';
import { useSession } from '../session';

/** Lines slower than this show their duration as a yellow pill. */
const SLOW_MS = 1000;

interface VisorState {
  events: TimelineEvent[];
  loading: boolean;
  error: unknown;
  /** The last page was short: there is nothing older (the визор keeps 7 days). */
  done: boolean;
}

export function Visor({ userId }: { userId: string }) {
  const { api } = useSession();
  const now = useNow();
  const [params, setParams] = useSearchParams();
  const around = params.get('at');
  // The filters live in state (quick clicks add up) and are copied to the address, so a link keeps them.
  const [shown, setShown] = useState(() => parseFilters(params.get('show')));
  const showParam = formatFilters(shown);
  const [state, setState] = useState<VisorState>({ events: [], loading: true, error: undefined, done: false });
  const [attempt, setAttempt] = useState(0);
  const more = useRef<AbortController | null>(null);

  // The first page: the newest lines, or those up to 10 minutes after the moment of a problem.
  useEffect(() => {
    more.current?.abort();
    const controller = new AbortController();
    setState({ events: [], loading: true, error: undefined, done: false });
    api.timeline(userId, around ? beforeForAround(around) : null, controller.signal).then(
      (page) => {
        if (!controller.signal.aborted) {
          setState({ events: page, loading: false, error: undefined, done: page.length < TIMELINE_LIMIT });
        }
      },
      (error: unknown) => {
        if (!controller.signal.aborted) setState((previous) => ({ ...previous, loading: false, error }));
      },
    );
    return () => controller.abort();
  }, [api, userId, around, attempt]);

  useEffect(() => () => more.current?.abort(), []);

  function loadMore() {
    const last = state.events.at(-1);
    if (!last || state.loading) return;
    const controller = new AbortController();
    more.current = controller;
    setState((previous) => ({ ...previous, loading: true, error: undefined }));
    api.timeline(userId, last.at, controller.signal).then(
      (page) => {
        if (controller.signal.aborted) return;
        setState((previous) => ({
          events: appendPage(previous.events, page),
          loading: false,
          error: undefined,
          done: page.length < TIMELINE_LIMIT,
        }));
      },
      (error: unknown) => {
        if (!controller.signal.aborted) setState((previous) => ({ ...previous, loading: false, error }));
      },
    );
  }

  function toggle(filter: KindFilter) {
    setShown((current) => {
      const next = new Set(current);
      if (next.has(filter)) next.delete(filter);
      else next.add(filter);
      return next;
    });
  }

  useEffect(() => {
    if (params.get('show') === showParam) return;
    setParams(
      (previous) => {
        const updated = new URLSearchParams(previous);
        if (showParam) updated.set('show', showParam);
        else updated.delete('show');
        return updated;
      },
      { replace: true },
    );
  }, [showParam, params, setParams]);

  const { events, loading, error, done } = state;
  const counts = countByFilter(events);
  const days = groupTimeline(events);
  const marked = around ? closestLine(events, around) : null;
  const visibleCount = events.filter((event) => isShown(event, shown)).length;

  // Opened around a problem: bring its line into view once it's there.
  const scrolled = useRef(false);
  useEffect(() => {
    if (!marked || scrolled.current) return;
    scrolled.current = true;
    document.getElementById('visor-marked')?.scrollIntoView?.({ block: 'center' });
  }, [marked]);

  return (
    <section className="visor" aria-labelledby="visor-title">
      <header className="visor-head">
        <h2 id="visor-title" className="visor-title">
          Визор
        </h2>
        <span className="muted">последние 7 дней, новые сверху</span>
      </header>

      <div className="visor-toolbar" role="group" aria-label="Что показывать">
        {KIND_FILTERS.map((filter) => (
          <Chip key={filter.id} pressed={shown.has(filter.id)} count={counts[filter.id]} onClick={() => toggle(filter.id)}>
            {filter.label}
          </Chip>
        ))}
      </div>

      {around && (
        <Notice icon="schedule">
          <p>
            Открыто вокруг {formatDateTime(around, now)}: показано то, что было до {formatTime(beforeForAround(around))},
            и раньше.{' '}
            <Link to={`/users/${userId}`} replace>
              Показать самое новое
            </Link>
          </p>
        </Notice>
      )}

      {events.length === 0 && loading && <Loading text="Загружаем визор…" />}
      {events.length === 0 && !loading && error === undefined && (
        <p className="empty">
          {around ? 'До этого момента за 7 дней ничего нет.' : 'За последние 7 дней человек ничего не делал в приложении.'}
        </p>
      )}
      {events.length > 0 && visibleCount === 0 && (
        <p className="empty">Среди загруженных событий ({events.length}) нет выбранных видов.</p>
      )}

      {days.map((day) => {
        const sessions = day.sessions
          .map((block) => ({ block, visible: block.events.filter((event) => isShown(event, shown)) }))
          .filter(({ visible }) => visible.length > 0);
        if (!sessions.length) return null;
        return (
          <div key={day.key} className="visor-day">
            <h3 className="visor-day-title">{formatDayHeading(day.date, now)}</h3>
            {sessions.map(({ block, visible }) => (
              <SessionCard key={block.key} block={block} visible={visible} marked={marked} />
            ))}
          </div>
        );
      })}

      {error !== undefined && <ErrorNotice error={error} onRetry={events.length ? loadMore : () => setAttempt((n) => n + 1)} />}

      {events.length > 0 && (
        <footer className="visor-foot">
          {!done && error === undefined && (
            <button type="button" className="button button--secondary" onClick={loadMore} disabled={loading}>
              {loading && <Spinner />}
              {loading ? 'Загружаем…' : 'Показать ещё'}
            </button>
          )}
          <p className="muted small">
            Загружено {formatCount(events.length, 'событие', 'события', 'событий')}: с{'\u00a0'}
            {formatDateTime(events[events.length - 1]!.at, now)} по {formatDateTime(events[0]!.at, now)}.
            {done && ' Это всё: визор хранит 7 дней.'}
          </p>
        </footer>
      )}
    </section>
  );
}

function SessionCard({
  block,
  visible,
  marked,
}: {
  block: SessionBlock;
  visible: TimelineEvent[];
  marked: TimelineEvent | null;
}) {
  const { lines, problems } = sessionSummary(block.events);
  const minutes = (Date.parse(block.last) - Date.parse(block.first)) / 60_000;
  return (
    <article className={`session${block.session ? '' : ' session--none'}`}>
      <header className="session-head">
        <span className="session-name">{block.session ? 'Сессия' : 'Без сессии'}</span>
        <span className="session-time">
          {formatTime(block.first)}–{formatTime(block.last)}
        </span>
        <span className="muted">{formatMinutes(minutes)}</span>
        {block.appVersion && <Badge>v{block.appVersion}</Badge>}
        <span className="muted">{formatCount(lines, 'событие', 'события', 'событий')}</span>
        {problems > 0 && (
          <Badge tone="danger" icon="error">
            {formatCount(problems, 'проблема', 'проблемы', 'проблем')}
          </Badge>
        )}
        {block.session && (
          <span className="session-id mono" title={`Сессия ${block.session}`}>
            {block.session.slice(0, 8)}
          </span>
        )}
      </header>
      <ol className="lines">
        {visible.map((event) => (
          <Line key={`${event.at}|${event.kind}|${event.text}`} event={event} marked={event === marked} />
        ))}
      </ol>
    </article>
  );
}

function Line({ event, marked }: { event: TimelineEvent; marked: boolean }) {
  const kind = timelineKind(event.kind);
  const problem = event.kind === 'error' || event.kind === 'crash';
  return (
    <li
      id={marked ? 'visor-marked' : undefined}
      className={`line line--${event.kind}${problem ? ' line--problem' : ''}${marked ? ' line--marked' : ''}`}
    >
      <time className="line-time" dateTime={event.at} title={formatFull(event.at)}>
        {formatTimeWithSeconds(event.at)}
      </time>
      <span className="line-kind">
        <Icon name={kind.icon} size={16} />
        {kind.label}
      </span>
      <span className="line-text" title={event.text}>
        <LineText event={event} />
      </span>
      <span className="line-meta">
        {event.status !== null && <Badge tone={statusTone(event.status)}>{event.status}</Badge>}
        {event.durationMs !== null &&
          (event.durationMs >= SLOW_MS ? (
            <Badge tone="warning" icon="schedule" title="Медленный ответ">
              {formatDurationMs(event.durationMs)}
            </Badge>
          ) : (
            <span className="line-duration">{formatDurationMs(event.durationMs)}</span>
          ))}
        {marked && (
          <Badge tone="warning" icon="schedule">
            этот момент
          </Badge>
        )}
      </span>
    </li>
  );
}

/** A request as "GET /api/v1/…" with the method in bold; ids shortened (the whole text is in the tooltip). */
function LineText({ event }: { event: TimelineEvent }) {
  const text = shortenIds(event.text);
  if (event.kind === 'request') {
    const space = text.indexOf(' ');
    const method = space > 0 ? text.slice(0, space) : '';
    if (/^[A-Z]+$/.test(method)) {
      return (
        <span className="mono">
          <strong>{method}</strong>
          {text.slice(space)}
        </span>
      );
    }
  }
  return <span className={event.kind === 'screen' ? 'mono' : undefined}>{text}</span>;
}
