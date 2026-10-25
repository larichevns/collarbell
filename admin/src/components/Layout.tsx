// The frame of every admin page: the header (logo, sections, who is signed in, "Выйти") and the page under it.
import { Link, NavLink, Outlet, ScrollRestoration } from 'react-router';
import { useSession } from '../session';
import { Badge, Icon } from './ui';

export function Layout() {
  const { me, mock, signOut } = useSession();
  return (
    <div className="shell">
      <a className="skip-link" href="#main">
        К содержимому
      </a>
      <header className="topbar">
        <div className="wrap topbar-row">
          <Link to="/" className="brand">
            <img src={`${import.meta.env.BASE_URL}favicon.svg`} alt="" width={28} height={28} />
            <span className="brand-name">Collarbell</span>
            <span className="brand-tag">админка</span>
          </Link>
          {mock && (
            <Badge tone="warning" title="npm run dev:mock: сервер и Firebase не используются">
              Тестовые данные
            </Badge>
          )}
          <nav className="nav" aria-label="Разделы">
            <NavLink to="/" end className="nav-link">
              <Icon name="dns" size={18} />
              Обзор
            </NavLink>
            <NavLink to="/users" className="nav-link">
              <Icon name="group" size={18} />
              Люди
            </NavLink>
            <NavLink to="/problems" className="nav-link">
              <Icon name="warning" size={18} />
              Проблемы
            </NavLink>
          </nav>
          <div className="account">
            {me.email && (
              <span className="account-email" title={me.email}>
                {me.email}
              </span>
            )}
            <button type="button" className="button button--ghost" onClick={signOut}>
              <Icon name="logout" size={18} />
              Выйти
            </button>
          </div>
        </div>
      </header>
      <main id="main" className="wrap main">
        <Outlet />
      </main>
      <ScrollRestoration />
    </div>
  );
}
