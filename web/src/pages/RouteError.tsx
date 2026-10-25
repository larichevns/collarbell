// When a page breaks while drawing (say, the server answered in a shape this app doesn't expect): a message instead
// of React Router's developer screen. The sidebar stays, so the other sections still open. And an address that
// leads nowhere.
import { Link, useRouteError } from 'react-router';
import { Icon } from '../components/Icon';
import { Notice, PageHead } from '../components/ui';
import { useI18n } from '../i18n/i18n';

export function RouteError() {
  const { t } = useI18n();
  const error = useRouteError();
  const detail = error instanceof Error ? error.message : null;
  return (
    <>
      <PageHead title={t.pageErrorTitle} />
      <Notice tone="danger">
        <p>{t.pageErrorBody}</p>
        {detail && <p className="mono small">{detail}</p>}
        <button type="button" className="button button--secondary" onClick={() => window.location.reload()}>
          {t.pageErrorReload}
        </button>
      </Notice>
    </>
  );
}

export function NotFoundPage() {
  const { t } = useI18n();
  return (
    <>
      <PageHead title={t.notFoundTitle} />
      <Link to="/" className="button button--primary">
        <Icon name="home" />
        {t.notFoundLink}
      </Link>
    </>
  );
}
