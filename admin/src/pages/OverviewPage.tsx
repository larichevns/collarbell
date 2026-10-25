// "Обзор": the numbers of the whole service in groups (Люди, Напоминания, Телефоны, AI, Сервер и ошибки) and the last
// alerts. What needs attention is listed on top and coloured on its tile (rules: lib/health.ts). Refreshes every
// minute while the tab is open, and right away when the owner comes back to the tab after a minute or more.
import { useEffect, useRef } from 'react';
import { Link } from 'react-router';
import { errorText } from '../api/client';
import type { Overview } from '../api/types';
import {
  Badge,
  BarList,
  Card,
  ErrorNotice,
  Icon,
  Loading,
  Meter,
  Notice,
  PageHead,
  RelativeTime,
  Section,
  Stat,
} from '../components/ui';
import {
  formatAge,
  formatBytes,
  formatCompact,
  formatFull,
  formatMinutes,
  formatNumber,
  formatPercent,
  formatTimeWithSeconds,
} from '../lib/format';
import { diskFreeShare, LATE_REMINDER_MINUTES, overviewIssues, toneOf, type Issue } from '../lib/health';
import { useNow, useResource } from '../lib/hooks';
import { alertKindLabel } from '../lib/labels';
import { useSession } from '../session';

export const REFRESH_MS = 60_000;

export function OverviewPage() {
  const { api } = useSession();
  const now = useNow(15_000);
  const { data, error, loading, reload } = useResource((signal) => api.overview(signal), [api]);

  const loadedAt = useRef(0);
  useEffect(() => {
    if (data) loadedAt.current = Date.now();
  }, [data]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      if (document.visibilityState === 'visible') reload();
    }, REFRESH_MS);
    const onVisibility = () => {
      if (document.visibilityState === 'visible' && Date.now() - loadedAt.current >= REFRESH_MS) reload();
    };
    document.addEventListener('visibilitychange', onVisibility);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [reload]);

  return (
    <>
      <PageHead
        title="Обзор"
        meta={
          data && (
            <>
              Данные на {formatTimeWithSeconds(data.generatedAt)} · обновляются каждую минуту
            </>
          )
        }
      >
        <button type="button" className="button button--secondary" onClick={reload} disabled={loading}>
          <Icon name="refresh" className={loading ? 'spin' : undefined} />
          Обновить
        </button>
      </PageHead>
      {error !== undefined && data && (
        <Notice tone="warning">
          Не удалось обновить: {errorText(error)} Показаны данные на {formatTimeWithSeconds(data.generatedAt)}.
        </Notice>
      )}
      {error !== undefined && !data && <ErrorNotice error={error} onRetry={reload} />}
      {error === undefined && !data && <Loading />}
      {data && <OverviewBody overview={data} now={now} refreshing={loading} />}
    </>
  );
}

function OverviewBody({ overview, now, refreshing }: { overview: Overview; now: Date; refreshing: boolean }) {
  const issues = overviewIssues(overview, now);
  const tone = (...ids: Issue['id'][]) => toneOf(issues, ...ids);
  const { people, reminders, devices, ai, api, server, alerts } = overview;
  const freeShare = diskFreeShare(overview);
  const late = reminders.oldestOverdueMinutes ?? 0;
  const versions = [...devices.appVersions].sort((a, b) => b.devices - a.devices);

  return (
    <div className={`overview${refreshing ? ' is-refreshing' : ''}`} aria-busy={refreshing}>
      <IssueList issues={issues} />

      <Section title="Люди" icon="group">
        <div className="stats stats--four">
          <Stat label="Пользователи" value={formatNumber(people.users)} hint="все аккаунты" to="/users" />
          <Stat label="Активны за 24 ч" value={formatNumber(people.activeToday)} hint={shareOf(people.activeToday, people.users)} />
          <Stat label="Активны за 7 дней" value={formatNumber(people.activeWeek)} hint={shareOf(people.activeWeek, people.users)} />
          <Stat label="Новые за 7 дней" value={formatNumber(people.newWeek)} hint="зарегистрировались" />
          <Stat label="Группы" value={formatNumber(people.households)} hint="все группы" />
          <Stat label="Общие группы" value={formatNumber(people.sharedHouseholds)} hint="больше одного человека" />
          <Stat
            label="Группы с Premium"
            value={people.premiumHouseholds === undefined ? '—' : formatNumber(people.premiumHouseholds)}
            hint={people.premiumHouseholds === undefined ? 'сервер не сообщил' : shareOf(people.premiumHouseholds, people.households, 'групп')}
          />
          <Stat label="Питомцы" value={formatNumber(people.pets)} hint="во всех группах" />
        </div>
      </Section>

      <Section title="Напоминания" icon="notifications" note="за 24 ч">
        <div className="stats">
          <Stat label="Отправлены" value={formatNumber(reminders.sent24h)} hint="переданы в Firebase" />
          <Stat
            label="Не отправлены"
            value={formatNumber(reminders.failed24h)}
            tone={tone('reminders-failed')}
            hint={reminders.failed24h > 0 ? 'Firebase не принял и после повторов' : 'всё ушло'}
          />
          <Stat
            label="Опоздали"
            value={formatNumber(reminders.expired24h)}
            tone={tone('reminders-expired')}
            hint={reminders.expired24h > 0 ? 'сервер не успел: не отправлены' : 'нет'}
          />
          <Stat label="Пропущены" value={formatNumber(reminders.skipped24h)} hint="уже не нужны или некому слать" />
          <Stat label="Ждут отправки" value={formatNumber(reminders.pending)} hint="запланированы" />
          <Stat
            label="Задержка отправки"
            value={late > 0 ? formatMinutes(late) : 'нет'}
            tone={tone('reminders-late')}
            hint={
              late > LATE_REMINDER_MINUTES
                ? `больше ${LATE_REMINDER_MINUTES} мин: отправка застряла`
                : `норма — до ${LATE_REMINDER_MINUTES} мин`
            }
          />
        </div>
      </Section>

      <Section title="Телефоны" icon="smartphone">
        <div className="split">
          <div className="stats stats--narrow">
            <Stat label="Android" value={formatNumber(devices.android)} hint={shareOf(devices.android, devices.android + devices.ios, 'телефонов')} />
            <Stat label="iOS" value={formatNumber(devices.ios)} hint={shareOf(devices.ios, devices.android + devices.ios, 'телефонов')} />
          </div>
          <Card title="Версии приложения" className="card--flat">
            {versions.length ? (
              <BarList
                caption="Телефоны по версиям приложения"
                rows={versions.map((row) => ({ key: row.version, label: row.version, value: row.devices }))}
              />
            ) : (
              <p className="muted">Телефонов ещё нет.</p>
            )}
          </Card>
        </div>
      </Section>

      <Section title="AI" icon="smart_toy">
        <div className="split">
          <div className="stats stats--narrow">
            <Stat
              label="Вызовы за 24 ч"
              value={formatNumber(ai.calls24h)}
              tone={tone('ai-failed')}
              hint={`с ошибкой: ${formatNumber(ai.failed24h)}`}
            />
            <Stat
              label="Вызовы за 30 дней"
              value={formatNumber(ai.calls30d)}
              hint={`с ошибкой: ${formatNumber(ai.failed30d)}${ai.calls30d ? ` (${formatPercent(ai.failed30d / ai.calls30d)})` : ''}`}
            />
            <Stat
              label="Токены на вход, 30 дней"
              value={formatCompact(ai.inputTokens30d)}
              title={formatNumber(ai.inputTokens30d)}
              hint="фото и вопросы"
            />
            <Stat
              label="Токены на выход, 30 дней"
              value={formatCompact(ai.outputTokens30d)}
              title={formatNumber(ai.outputTokens30d)}
              hint="ответы модели"
            />
          </div>
          <Card title="Модели за 30 дней" className="card--flat">
            {ai.models30d.length ? (
              <table className="table table--compact">
                <thead>
                  <tr>
                    <th scope="col">Модель</th>
                    <th scope="col" className="num">
                      Вызовы
                    </th>
                    <th scope="col" className="num">
                      С ошибкой
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {[...ai.models30d]
                    .sort((a, b) => b.calls - a.calls)
                    .map((model) => (
                      <tr key={model.model}>
                        <td className="mono">{model.model}</td>
                        <td className="num">{formatNumber(model.calls)}</td>
                        <td className="num">
                          {model.failed > 0 ? (
                            <Badge tone="warning">{formatNumber(model.failed)}</Badge>
                          ) : (
                            formatNumber(model.failed)
                          )}
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
            ) : (
              <p className="muted">За 30 дней AI не вызывали.</p>
            )}
          </Card>
        </div>
      </Section>

      <Section title="Сервер и ошибки" icon="dns" note="за 24 ч">
        <div className="stats">
          <Stat label="Запросы к API" value={formatNumber(api.requests24h)} hint="от всех телефонов" />
          <Stat
            label="Ошибки сервера"
            value={formatNumber(api.serverErrors24h)}
            tone={tone('server-errors')}
            hint={api.serverErrors24h > 0 ? 'ответы 5xx — смотреть' : 'ответов 5xx нет'}
            to="/problems?kind=server"
          />
          <Stat
            label="Ошибки в приложении"
            value={formatNumber(api.appErrors24h)}
            hint="что видели люди"
            to="/problems?kind=app-error"
          />
          <Stat
            label="Сбои приложения"
            value={formatNumber(api.crashes24h)}
            tone={tone('crashes')}
            hint={api.crashes24h > 0 ? 'приложение падало' : 'не падало'}
            to="/problems?kind=crash"
          />
          <Stat
            label="Свободно на диске"
            value={freeShare === null ? 'нет данных' : formatBytes(server.diskFreeBytes)}
            tone={tone('disk-low')}
            hint={
              freeShare === null
                ? 'сервер не сообщил'
                : `${formatPercent(freeShare)} из ${formatBytes(server.diskTotalBytes)}${freeShare < 0.1 ? ' — мало' : ''}`
            }
          >
            {freeShare !== null && (
              <Meter
                value={1 - freeShare}
                tone={freeShare < 0.1 ? 'danger' : 'ok'}
                label={`Занято ${formatPercent(1 - freeShare)} диска`}
              />
            )}
          </Stat>
          <Stat
            label="Копия базы сделана"
            value={server.lastBackupAt ? `${formatAge(server.lastBackupAt, now)} назад` : 'нет'}
            tone={tone('backup-old', 'backup-missing')}
            title={server.lastBackupAt ? formatFull(server.lastBackupAt) : undefined}
            hint={
              server.lastBackupAt === null
                ? 'копий не найдено'
                : `${server.lastBackupBytes !== null ? `${formatBytes(server.lastBackupBytes)} · ` : ''}${
                    tone('backup-old') ? 'старше 26 ч' : 'каждую ночь'
                  }`
            }
          />
        </div>
      </Section>

      <Section title="Оповещения" icon="notifications">
        <Card className="card--flat">
          <p className="alerts-status">
            {alerts.telegramConfigured ? (
              <Badge tone="ok" icon="check_circle">
                Telegram настроен
              </Badge>
            ) : (
              <Badge tone="warning" icon="warning">
                Telegram не настроен
              </Badge>
            )}
            <span className="muted">
              {alerts.telegramConfigured
                ? 'Сервер пишет владельцу, когда что-то не так; одно и то же — не чаще раза в несколько часов.'
                : 'Оповещения пишутся только в лог сервера.'}
            </span>
          </p>
          {alerts.recent.length ? (
            <ul className="alerts">
              {alerts.recent.map((alert) => (
                <li key={`${alert.kind}|${alert.sentAt}`} className="alert-row">
                  <span className="alert-kind">{alertKindLabel(alert.kind)}</span>
                  <span className="alert-text">{alert.text}</span>
                  <span className="alert-time muted">
                    <RelativeTime value={alert.sentAt} now={now} />
                  </span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="muted">Оповещений ещё не было.</p>
          )}
        </Card>
      </Section>
    </div>
  );
}

/** «18 % от всех», for a part of a whole. */
function shareOf(part: number, whole: number, of = 'всех'): string {
  return whole > 0 ? `${formatPercent(part / whole)} ${of}` : '—';
}

function IssueList({ issues }: { issues: Issue[] }) {
  if (!issues.length) {
    return (
      <Notice tone="ok">
        <p>
          <strong>Всё спокойно.</strong> Напоминания уходят, ошибок сервера нет, диск и копии базы в порядке.
        </p>
      </Notice>
    );
  }
  const danger = issues.some((issue) => issue.tone === 'danger');
  return (
    <section className={`issues issues--${danger ? 'danger' : 'warning'}`} aria-labelledby="issues-title">
      <h2 id="issues-title" className="issues-title">
        <Icon name={danger ? 'error' : 'warning'} />
        Требует внимания
      </h2>
      <ul className="issues-list">
        {issues.map((issue) => (
          <li key={issue.id} className={`issue issue--${issue.tone}`}>
            <Icon name={issue.tone === 'danger' ? 'error' : 'warning'} size={18} />
            <span>
              {issue.text}
              {issue.to && (
                <Link to={issue.to} className="issue-link">
                  Смотреть
                </Link>
              )}
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}
