// "Проблемы": server errors (5xx), errors people saw in the app, and crashes, newest first, by day. The period and
// the kind are kept in the address (?hours=24&kind=server). Each row opens the person's визор around that moment.
import { Link, useSearchParams } from 'react-router';
import type { Problem, ProblemKind } from '../api/types';
import { Badge, Empty, ErrorNotice, Icon, Loading, PageHead, RelativeTime, Segmented } from '../components/ui';
import { dayKey, formatDayHeading, formatFull, formatTimeWithSeconds, shortenIds } from '../lib/format';
import { useNow, useResource } from '../lib/hooks';
import { problemKindLabel, problemKindPlural } from '../lib/labels';
import { useSession } from '../session';

const PERIODS = [
  { value: 1, label: '1 ч' },
  { value: 24, label: '24 ч' },
  { value: 72, label: '3 дня' },
  { value: 168, label: '7 дней' },
] as const;

type Period = (typeof PERIODS)[number]['value'];
type KindChoice = ProblemKind | 'all';

const KINDS: readonly KindChoice[] = ['all', 'server', 'app-error', 'crash'];

function parsePeriod(value: string | null): Period {
  return PERIODS.find((period) => String(period.value) === value)?.value ?? 24;
}

function parseKind(value: string | null): KindChoice {
  return KINDS.find((kind) => kind === value) ?? 'all';
}

export function ProblemsPage() {
  const { api } = useSession();
  const now = useNow();
  const [params, setParams] = useSearchParams();
  const hours = parsePeriod(params.get('hours'));
  const kind = parseKind(params.get('kind'));
  const { data, error, loading, reload } = useResource((signal) => api.problems(hours, signal), [api, hours]);

  function choose(name: 'hours' | 'kind', value: string, fallback: string) {
    setParams(
      (previous) => {
        const updated = new URLSearchParams(previous);
        if (value === fallback) updated.delete(name);
        else updated.set(name, value);
        return updated;
      },
      { replace: true },
    );
  }

  const all = data ?? [];
  const counts: Record<KindChoice, number> = { all: all.length, server: 0, 'app-error': 0, crash: 0 };
  for (const problem of all) counts[problem.kind] = (counts[problem.kind] ?? 0) + 1;
  const rows = kind === 'all' ? all : all.filter((problem) => problem.kind === kind);

  return (
    <>
      <PageHead title="Проблемы">
        <button type="button" className="button button--secondary" onClick={reload} disabled={loading}>
          <Icon name="refresh" className={loading ? 'spin' : undefined} />
          Обновить
        </button>
      </PageHead>
      <div className="toolbar toolbar--filters">
        <Segmented
          label="Период"
          value={hours}
          options={PERIODS}
          onChange={(value) => choose('hours', String(value), '24')}
        />
        <Segmented
          label="Вид"
          value={kind}
          options={KINDS.map((value) => ({
            value,
            label: value === 'all' ? 'Все' : problemKindPlural(value),
            count: data ? counts[value] : undefined,
          }))}
          onChange={(value) => choose('kind', value, 'all')}
        />
      </div>
      {error !== undefined && <ErrorNotice error={error} onRetry={reload} />}
      {!data && error === undefined && <Loading />}
      {data && rows.length === 0 && (
        <Empty>{all.length ? 'Таких проблем за это время нет.' : 'За это время проблем не было.'}</Empty>
      )}
      {data && rows.length > 0 && (
        <div className={loading ? 'is-refreshing' : undefined}>
          {byDay(rows).map(([key, dayRows]) => (
            <section key={key} className="problem-day">
              <h2 className="visor-day-title">{formatDayHeading(dayRows[0]!.at, now)}</h2>
              <ul className="problems">
                {dayRows.map((problem, index) => (
                  <ProblemRow key={`${problem.at}|${problem.kind}|${index}`} problem={problem} now={now} />
                ))}
              </ul>
            </section>
          ))}
        </div>
      )}
    </>
  );
}

function byDay(rows: Problem[]): [string, Problem[]][] {
  const days = new Map<string, Problem[]>();
  for (const row of rows) {
    const key = dayKey(row.at);
    const list = days.get(key);
    if (list) list.push(row);
    else days.set(key, [row]);
  }
  return [...days];
}

function ProblemRow({ problem, now }: { problem: Problem; now: Date }) {
  const tone = problem.kind === 'app-error' ? 'warning' : 'danger';
  const icon = problem.kind === 'crash' ? 'bug_report' : problem.kind === 'server' ? 'dns' : 'error';
  // A server error's text already holds its path ("PUT /api/v1/… → 500").
  const path = problem.path && !problem.text.includes(problem.path) ? problem.path : null;
  return (
    <li className="problem">
      <div className="problem-when">
        <time dateTime={problem.at} title={formatFull(problem.at)}>
          {formatTimeWithSeconds(problem.at)}
        </time>
        <span className="muted small">
          <RelativeTime value={problem.at} now={now} />
        </span>
      </div>
      <div className="problem-main">
        <div className="problem-head">
          <Badge tone={tone} icon={icon}>
            {problemKindLabel(problem.kind)}
            {problem.status !== null && ` ${problem.status}`}
          </Badge>
          {problem.userId ? (
            <Link to={`/users/${problem.userId}`} className="problem-person">
              {problem.email ?? 'без e-mail'}
            </Link>
          ) : (
            <span className="muted">без пользователя</span>
          )}
        </div>
        <p className="problem-text mono" title={problem.text}>
          {shortenIds(problem.text)}
        </p>
        {path && (
          <p className="muted small mono" title={path}>
            {shortenIds(path)}
          </p>
        )}
      </div>
      {problem.userId && (
        <Link
          to={`/users/${problem.userId}?at=${encodeURIComponent(problem.at)}`}
          className="button button--secondary problem-open"
        >
          В визоре
          <Icon name="chevron_right" size={18} />
        </Link>
      )}
    </li>
  );
}
