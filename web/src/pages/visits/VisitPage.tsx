// One visit: when, for whom, where, the reminders and notes, and what to do with it: "The visit took place" once its
// day has come, and for everyone but helpers "Edit", "Cancel visit" (or "Plan again") and "Delete".
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { data } from '../../api/client';
import { errorMessage, isNotFound } from '../../api/errors';
import { keys } from '../../api/keys';
import { usePets, useVisit } from '../../api/queries';
import type { Visit, VisitStatus } from '../../api/types';
import { ConfirmDialog } from '../../components/Dialog';
import { Icon } from '../../components/Icon';
import { VISIT_TYPE_ICONS } from '../../components/kindIcons';
import { useToast } from '../../components/Toasts';
import { ErrorNotice, Loading, Notice, PageHead, Section } from '../../components/ui';
import { useHouseholdDate } from '../../household/date';
import { useApi, useHousehold } from '../../household/household';
import { useI18n } from '../../i18n/i18n';
import { visitReminderLabel, visitWhen } from '../../lib/labels';
import { VisitDoneDialog } from './VisitDoneDialog';

export function VisitPage() {
  const { id = '' } = useParams();
  const i18n = useI18n();
  const { t } = i18n;
  const api = useApi();
  const { current, permissions } = useHousehold();
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const toast = useToast();
  const today = useHouseholdDate();
  const visit = useVisit(id);
  const pets = usePets().data ?? [];
  const [asking, setAsking] = useState<'cancel' | 'delete' | null>(null);
  const [marking, setMarking] = useState(false);
  const [busy, setBusy] = useState(false);

  const back = { to: '/visits', label: t.visitsTitle };
  // Deleted (here or on another phone): the old copy is not shown as if the visit were planned.
  if (!visit.data || isNotFound(visit.error)) {
    return (
      <>
        <PageHead back={back} title={t.visitsTitle} />
        {visit.error ? <ErrorNotice error={visit.error} onRetry={() => void visit.refetch()} /> : <Loading />}
      </>
    );
  }
  const value = visit.data;
  const planned = value.status === 'Planned';
  const refresh = () => {
    void queryClient.invalidateQueries({ queryKey: keys.visits(current.id) });
    void queryClient.invalidateQueries({ queryKey: keys.todayAll(current.id) });
  };

  /** Cancels the visit or plans it again: the whole visit is sent back, as the server has it now. */
  async function setStatus(status: VisitStatus) {
    setBusy(true);
    try {
      const fresh: Visit = await data(api.GET('/api/v1/appointments/{id}', { params: { path: { id } } }));
      await api.PUT('/api/v1/appointments/{id}', {
        params: { path: { id } },
        body: {
          type: fresh.type,
          title: fresh.title,
          date: fresh.date,
          time: fresh.time,
          durationMinutes: fresh.durationMinutes,
          location: fresh.location,
          notes: fresh.notes,
          petIds: fresh.petIds,
          remindOffsetsMinutes: fresh.remindOffsetsMinutes,
          status,
          requestId: null,
        },
      });
    } catch (error) {
      toast(errorMessage(t, error));
    } finally {
      setBusy(false);
      setAsking(null);
      refresh();
    }
  }

  async function remove() {
    setBusy(true);
    try {
      await api.DELETE('/api/v1/appointments/{id}', { params: { path: { id } } });
      queryClient.removeQueries({ queryKey: keys.visit(current.id, id), exact: true });
      refresh();
      void navigate('/visits');
    } catch (error) {
      // Deleted on another device already: that is what was wanted.
      if (isNotFound(error)) {
        queryClient.removeQueries({ queryKey: keys.visit(current.id, id), exact: true });
        refresh();
        void navigate('/visits');
        return;
      }
      toast(errorMessage(t, error));
      setBusy(false);
      setAsking(null);
    }
  }

  const names = value.petIds.map((petId) => pets.find((pet) => pet.id === petId));
  return (
    <>
      <PageHead
        back={back}
        title={value.title}
        actions={
          permissions.canEdit && (
            <>
              {value.status !== 'Done' && (
                <Link to={`/visits/${id}/edit`} className="button button--secondary">
                  <Icon name="edit" />
                  {t.commonEdit}
                </Link>
              )}
              {planned && (
                <button
                  type="button"
                  className="button button--secondary"
                  onClick={() => setAsking('cancel')}
                  disabled={busy}
                >
                  {t.visitCancel}
                </button>
              )}
              {value.status === 'Cancelled' && (
                <button
                  type="button"
                  className="button button--secondary"
                  onClick={() => void setStatus('Planned')}
                  disabled={busy}
                >
                  {t.visitPlanAgain}
                </button>
              )}
              <button
                type="button"
                className="button button--ghost button--danger-text"
                onClick={() => setAsking('delete')}
                disabled={busy}
              >
                <Icon name="delete" />
                {t.visitDelete}
              </button>
            </>
          )
        }
      />
      {value.status === 'Cancelled' && <Notice tone="warning">{t.visitCancelledNote}</Notice>}
      <div className="card visit-card">
        <p className="visit-type">
          <Icon name={VISIT_TYPE_ICONS[value.type]} />
          {t.visitType[value.type]}
        </p>
        <p className="visit-when">{visitWhen(i18n, value.date, value.time, today)}</p>
        <dl className="facts">
          <div className="fact">
            <dt>{t.visitPetsLabel}</dt>
            <dd>
              {names.map((pet, index) => (
                <span key={value.petIds[index]}>
                  {index > 0 && ', '}
                  {pet ? <Link to={`/pets/${pet.id}`}>{pet.name}</Link> : '…'}
                </span>
              ))}
            </dd>
          </div>
          {value.location && (
            <div className="fact">
              <dt>{t.visitLocationLabel}</dt>
              <dd>{value.location}</dd>
            </div>
          )}
          <div className="fact">
            <dt>{t.visitRemindersLabel}</dt>
            <dd>
              {value.remindOffsetsMinutes.length
                ? value.remindOffsetsMinutes.map((minutes) => visitReminderLabel(t, minutes)).join(', ')
                : t.visitRemindersNone}
            </dd>
          </div>
          {value.notes && (
            <div className="fact">
              <dt>{t.visitNotesLabel}</dt>
              <dd className="pre-line">{value.notes}</dd>
            </div>
          )}
        </dl>
        {planned && value.date <= today && (
          <button type="button" className="button button--primary" onClick={() => setMarking(true)}>
            <Icon name="check" />
            {t.visitDone}
          </button>
        )}
      </div>
      {value.status === 'Done' && (
        <Section title={t.visitResultTitle}>
          {value.recordIds.length === 0 ? (
            <p className="muted">{t.visitNoRecords}</p>
          ) : (
            <ul className="card card--list rows">
              {names.map(
                (pet) =>
                  pet && (
                    <li key={pet.id} className="row">
                      <Icon name="event_note" className="row-icon" />
                      <div className="row-main">
                        <Link to={`/pets/${pet.id}`} className="row-title row-link">
                          {pet.name}
                        </Link>
                        <span className="row-sub">{t.visitRecordsOfPet}</span>
                      </div>
                      <Icon name="chevron_right" className="row-arrow" />
                    </li>
                  ),
              )}
            </ul>
          )}
        </Section>
      )}
      {marking && <VisitDoneDialog visit={value} onClose={() => setMarking(false)} />}
      {asking === 'cancel' && (
        <ConfirmDialog
          title={t.visitCancelTitle}
          body={t.visitCancelBody}
          confirmLabel={t.visitCancel}
          danger
          busy={busy}
          onConfirm={() => void setStatus('Cancelled')}
          onCancel={() => setAsking(null)}
        />
      )}
      {asking === 'delete' && (
        <ConfirmDialog
          title={t.visitDeleteTitle}
          body={t.visitDeleteBody}
          confirmLabel={t.commonDelete}
          danger
          busy={busy}
          onConfirm={() => void remove()}
          onCancel={() => setAsking(null)}
        />
      )}
    </>
  );
}
