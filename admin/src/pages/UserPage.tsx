// "Человек": the profile, their groups (→ the group; role and plan), phones, AI use, and the визор below.
import { Link } from 'react-router';
import { isNotFound } from '../api/client';
import type { UserDetail } from '../api/types';
import { Badge, Card, Empty, ErrorNotice, Loading, PageHead, RelativeTime } from '../components/ui';
import { formatCompact, formatCount, formatDate, formatFull, formatNumber, formatPercent } from '../lib/format';
import { useNow, useResource } from '../lib/hooks';
import { personName, platformLabel, roleLabel } from '../lib/labels';
import { useSession } from '../session';
import { Visor } from './Visor';

export function UserPage({ id }: { id: string }) {
  const { api } = useSession();
  const now = useNow();
  const { data, error, reload } = useResource((signal) => api.user(id, signal), [api, id]);

  if (isNotFound(error)) {
    return (
      <>
        <PageHead title="Человек не найден" back={{ to: '/users', label: 'Люди' }} />
        <Empty>Такого аккаунта нет: возможно, его удалили.</Empty>
      </>
    );
  }

  return (
    <>
      <PageHead
        title={data ? personName(data) : 'Человек'}
        back={{ to: '/users', label: 'Люди' }}
        meta={data && <UserMeta user={data} now={now} />}
      />
      {error !== undefined && <ErrorNotice error={error} onRetry={reload} />}
      {!data && error === undefined && <Loading />}
      {data && <UserCards user={data} now={now} />}
      <Visor userId={id} />
    </>
  );
}

function UserMeta({ user, now }: { user: UserDetail; now: Date }) {
  return (
    <>
      {user.displayName && user.email && <span>{user.email}</span>}
      {!user.displayName && <span>имя не указано</span>}
      <span>
        в Collarbell с <span title={formatFull(user.createdAt)}>{formatDate(user.createdAt, now)}</span>
      </span>
      <span>
        {user.lastSeenAt ? (
          <>
            последний раз <RelativeTime value={user.lastSeenAt} now={now} />
          </>
        ) : (
          'в приложении ещё не был'
        )}
      </span>
      {user.locale && <span>язык {user.locale}</span>}
      {user.timeZone && <span>пояс {user.timeZone}</span>}
      <span className="mono" title={user.id}>
        id {user.id.slice(0, 8)}
      </span>
    </>
  );
}

function UserCards({ user, now }: { user: UserDetail; now: Date }) {
  const { ai } = user;
  return (
    <div className="cards">
      <Card title="Группы" icon="group">
        {user.households.length ? (
          <ul className="list">
            {user.households.map((household) => (
              <li key={household.id} className="list-row">
                <Link to={`/households/${household.id}`} className="list-main">
                  {household.name}
                </Link>
                <Badge>{roleLabel(household.role)}</Badge>
                <Badge tone={household.plan === 'Premium' ? 'ok' : 'neutral'} icon="workspace_premium" title="Тариф группы">
                  {household.plan ?? '—'}
                </Badge>
                <span className="list-note muted">
                  {formatCount(household.memberCount, 'человек', 'человека', 'человек')} ·{' '}
                  {formatCount(household.pets, 'питомец', 'питомца', 'питомцев')}
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="muted">Ни в одной группе.</p>
        )}
      </Card>

      <Card title="Телефоны" icon="smartphone">
        {user.devices.length ? (
          <ul className="list">
            {user.devices.map((device, index) => (
              <li key={`${device.platform}|${device.appVersion}|${index}`} className="list-row">
                <span className="list-main">{platformLabel(device.platform)}</span>
                {device.appVersion ? <Badge>v{device.appVersion}</Badge> : <Badge>версия ?</Badge>}
                <span className="list-note muted">
                  <RelativeTime value={device.lastSeenAt} now={now} />
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="muted">Телефонов нет: пуши этому человеку не придут.</p>
        )}
      </Card>

      <Card title="AI за 30 дней" icon="smart_toy">
        <dl className="facts">
          <dt>Вызовы</dt>
          <dd>{formatNumber(ai.calls30d)}</dd>
          <dt>С ошибкой</dt>
          <dd>
            {ai.failed30d > 0 ? (
              <Badge tone="warning" icon="warning">
                {formatNumber(ai.failed30d)}
                {ai.calls30d > 0 && ` (${formatPercent(ai.failed30d / ai.calls30d)})`}
              </Badge>
            ) : (
              '0'
            )}
          </dd>
          <dt>Токены на вход</dt>
          <dd title={formatNumber(ai.inputTokens30d)}>{formatCompact(ai.inputTokens30d)}</dd>
          <dt>Токены на выход</dt>
          <dd title={formatNumber(ai.outputTokens30d)}>{formatCompact(ai.outputTokens30d)}</dd>
        </dl>
        <p className="muted small">Считаются вызовы всех групп этого человека.</p>
      </Card>
    </div>
  );
}
