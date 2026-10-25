// "Люди": search by e-mail or name (an empty search: the newest accounts), a table, a row opens the person.
// The search is kept in the address (?q=…), so "back" from a person returns to the same list.
import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router';
import { USERS_LIMIT } from '../api/client';
import type { UserRow } from '../api/types';
import { Empty, ErrorNotice, Icon, Loading, PageHead, RelativeTime } from '../components/ui';
import { formatCount, formatDate, formatFull, formatNumber } from '../lib/format';
import { useDebounced, useNow, useResource } from '../lib/hooks';
import { personName } from '../lib/labels';
import { useSession } from '../session';

export const SEARCH_DELAY_MS = 300;

export function UsersPage() {
  const { api } = useSession();
  const now = useNow();
  const [params, setParams] = useSearchParams();
  const [text, setText] = useState(() => params.get('q') ?? '');
  const query = useDebounced(text.trim(), SEARCH_DELAY_MS);

  useEffect(() => {
    if ((params.get('q') ?? '') !== query) setParams(query ? { q: query } : {}, { replace: true });
  }, [query, params, setParams]);

  const { data, error, loading, reload } = useResource((signal) => api.users(query, signal), [api, query]);

  return (
    <>
      <PageHead title="Люди" />
      <div className="toolbar">
        <label className="search">
          <Icon name="search" />
          <span className="visually-hidden">Поиск</span>
          <input
            className="input search-input"
            type="search"
            placeholder="E-mail или имя"
            value={text}
            autoFocus
            onChange={(event) => setText(event.target.value)}
          />
        </label>
        {data && <p className="toolbar-note muted">{summary(data, query)}</p>}
      </div>
      {error !== undefined && <ErrorNotice error={error} onRetry={reload} />}
      {!data && error === undefined && <Loading />}
      {data && data.length === 0 && (
        <Empty>{query ? `Никого не нашли по «${query}».` : 'Пользователей ещё нет.'}</Empty>
      )}
      {data && data.length > 0 && (
        <div className={`table-wrap${loading ? ' is-refreshing' : ''}`}>
          <table className="table table--rows">
            <thead>
              <tr>
                <th scope="col">Человек</th>
                <th scope="col" className="hide-sm">
                  Аккаунт создан
                </th>
                <th scope="col">Был в приложении</th>
                <th scope="col" className="num hide-sm">
                  Группы
                </th>
                <th scope="col" className="num hide-sm">
                  Телефоны
                </th>
                <th scope="col" className="num hide-sm">
                  AI за 30 дней
                </th>
              </tr>
            </thead>
            <tbody>
              {data.map((user) => (
                <UserTableRow key={user.id} user={user} now={now} />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

function UserTableRow({ user, now }: { user: UserRow; now: Date }) {
  return (
    <tr className="row-link">
      <td>
        <Link to={`/users/${user.id}`} className="row-main">
          {personName(user)}
        </Link>
        {user.displayName && user.email && <div className="muted small">{user.email}</div>}
      </td>
      <td className="hide-sm" title={formatFull(user.createdAt)}>
        {formatDate(user.createdAt, now)}
      </td>
      <td>{user.lastSeenAt ? <RelativeTime value={user.lastSeenAt} now={now} /> : <span className="muted">ещё нет</span>}</td>
      <td className="num hide-sm">{formatNumber(user.households)}</td>
      <td className="num hide-sm">{formatNumber(user.devices)}</td>
      <td className="num hide-sm">{formatNumber(user.aiCalls30d)}</td>
    </tr>
  );
}

function summary(rows: UserRow[], query: string): string {
  if (rows.length >= USERS_LIMIT) {
    return query
      ? `Показаны первые ${USERS_LIMIT} — уточните поиск.`
      : `Показаны ${USERS_LIMIT} новых; остальных — поиском.`;
  }
  if (!query) return 'Новые сверху.';
  return `Найдено: ${formatCount(rows.length, 'человек', 'человека', 'человек')}.`;
}
