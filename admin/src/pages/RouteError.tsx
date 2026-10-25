// When a page breaks while drawing (say, the server answered in a shape this admin doesn't expect): a message in
// Russian instead of React Router's developer screen. The header stays, so the other sections still open.
import { useRouteError } from 'react-router';
import { Notice, PageHead } from '../components/ui';

export function RouteError() {
  const error = useRouteError();
  const detail = error instanceof Error ? error.message : null;
  return (
    <div className="route-error">
      <PageHead title="Что-то пошло не так" />
      <Notice tone="danger">
        <p>Страница не смогла показать ответ сервера. Обновите страницу; если не поможет, подробности — в консоли браузера.</p>
        {detail && <p className="mono small">{detail}</p>}
        <button type="button" className="button button--secondary" onClick={() => window.location.reload()}>
          Обновить страницу
        </button>
      </Notice>
    </div>
  );
}
