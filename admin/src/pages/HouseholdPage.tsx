// "Группа": how much it holds (pets, feeding schedules, plans, supplies, invites), its plan (Free or Premium, with the
// admin's actions: PlanCard) and who is in it with which role.
import { Link, useLocation, useNavigate } from 'react-router';
import { isNotFound } from '../api/client';
import type { AdminPlan, HouseholdDetail } from '../api/types';
import { Badge, Card, Empty, ErrorNotice, Icon, Loading, PageHead, Stat } from '../components/ui';
import { formatDate, formatFull, formatNumber } from '../lib/format';
import { useNow, useResource } from '../lib/hooks';
import { personName, roleLabel } from '../lib/labels';
import { useSession } from '../session';
import { PlanCard } from './PlanCard';

export function HouseholdPage({ id }: { id: string }) {
  const { api } = useSession();
  const now = useNow();
  const { data, error, reload, update } = useResource((signal) => api.household(id, signal), [api, id]);

  if (isNotFound(error)) {
    return (
      <>
        <PageHead title="Группа не найдена" />
        <BackLink />
        <Empty>Такой группы нет: возможно, её удалили.</Empty>
      </>
    );
  }

  return (
    <>
      <BackLink />
      <PageHead
        title={data ? data.name : 'Группа'}
        meta={
          data && (
            <>
              <span>Группа</span>
              <span>часовой пояс {data.timeZone}</span>
              <span>
                создана <span title={formatFull(data.createdAt)}>{formatDate(data.createdAt, now)}</span>
              </span>
            </>
          )
        }
      />
      {error !== undefined && <ErrorNotice error={error} onRetry={reload} />}
      {!data && error === undefined && <Loading />}
      {data && (
        <HouseholdBody
          household={data}
          now={now}
          onPlanChange={(plan) => update((household) => ({ ...household, plan }))}
        />
      )}
    </>
  );
}

/** Back where the owner came from (a person, the визор); opened by a link from elsewhere: to "Люди". */
function BackLink() {
  const location = useLocation();
  const navigate = useNavigate();
  if (location.key === 'default') {
    return (
      <Link to="/users" className="back-link">
        <Icon name="arrow_back" size={18} />
        Люди
      </Link>
    );
  }
  return (
    <button type="button" className="back-link" onClick={() => navigate(-1)}>
      <Icon name="arrow_back" size={18} />
      Назад
    </button>
  );
}

function HouseholdBody({
  household,
  now,
  onPlanChange,
}: {
  household: HouseholdDetail;
  now: Date;
  onPlanChange: (plan: AdminPlan) => void;
}) {
  return (
    <div className="stack">
      <div className="stats">
        <Stat label="Люди" value={formatNumber(household.members.length)} />
        <Stat label="Питомцы" value={formatNumber(household.pets)} />
        <Stat label="Расписания кормления" value={formatNumber(household.routines)} />
        <Stat label="Планы ухода" value={formatNumber(household.carePlans)} />
        <Stat label="Запасы" value={formatNumber(household.supplies)} />
        <Stat label="Открытые приглашения" value={formatNumber(household.openInvites)} />
      </div>
      <div className="split">
        {household.plan ? (
          <PlanCard householdId={household.id} householdName={household.name} plan={household.plan} onChange={onPlanChange} />
        ) : (
          <Card title="Тариф" icon="workspace_premium">
            <p className="muted">Сервер не прислал тариф этой группы.</p>
          </Card>
        )}
        <Card title="Участники" icon="group">
          <table className="table table--rows">
            <thead>
              <tr>
                <th scope="col">Человек</th>
                <th scope="col">Роль</th>
                <th scope="col" className="hide-sm">
                  В группе с
                </th>
              </tr>
            </thead>
            <tbody>
              {household.members.map((member) => (
                <tr key={member.userId} className="row-link">
                  <td>
                    <Link to={`/users/${member.userId}`} className="row-main">
                      {personName(member)}
                    </Link>
                    {member.displayName && member.email && <div className="muted small">{member.email}</div>}
                  </td>
                  <td>
                    <Badge>{roleLabel(member.role)}</Badge>
                  </td>
                  <td className="hide-sm" title={formatFull(member.joinedAt)}>
                    {formatDate(member.joinedAt, now)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      </div>
    </div>
  );
}
