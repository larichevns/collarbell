// The frame of every page. On a wide screen, a sidebar: the page's header, with the sections, the group on screen (a
// switch when the person is in several), the language and the account. On a phone's width, a top bar whose "Menu"
// opens the same. The page is under the strip that says the server can't be reached.
//
// Another group opens the section's first page: nothing of the other group stays on screen, and a form with typed
// input asks first (the switch waits for the move, which the form may stop). When the group on screen goes away
// (the person was removed from it), the move happens without asking: there is nothing left to save the form to.
// Every page of the history remembers the group it was shown in: Back or Forward to a page of another group opens
// that group again (or the section's start, when the person isn't in it any more), not the page in this group.
//
// A file dropped anywhere but a drop zone (or onto one that is busy) is ignored, rather than opened by the browser
// in place of the app.
import { useEffect, useEffectEvent, useRef, useState } from 'react';
import { Link, NavLink, Outlet, ScrollRestoration, useLocation, useNavigate } from 'react-router';
import { useHousehold } from '../household/household';
import { useI18n } from '../i18n/i18n';
import { LANGS } from '../i18n/lang';
import { householdName } from '../lib/labels';
import { LiveStatusBadge } from '../live/LiveProvider';
import { useSession } from '../session';
import { SelectField } from './fields';
import { Icon } from './Icon';
import { FORCED_MOVE, LeaveGuardProvider } from './LeaveGuard';
import { OfflineBanner } from './OfflineBanner';
import { Loading } from './ui';

/** "/pets/42/edit" → "/pets": where a section starts. */
function sectionOf(pathname: string): string {
  const first = pathname.split('/')[1];
  return first ? `/${first}` : '/';
}

/**
 * Another group on screen, as the sidebar's picker does it: the section's first page opens in that group, and a form
 * with typed input asks first.
 */
export function useSwitchHousehold(): (id: string) => void {
  const location = useLocation();
  const navigate = useNavigate();
  return (id) => {
    const section = sectionOf(location.pathname);
    void navigate(section, { state: { household: id }, replace: section === location.pathname });
  };
}

export function Layout() {
  const { t } = useI18n();
  const { current, households, switchTo } = useHousehold();
  const location = useLocation();
  const navigate = useNavigate();
  const [menuOpen, setMenuOpen] = useState(false);

  // A new page closes the menu.
  useEffect(() => setMenuOpen(false), [location.pathname]);

  // The switch asked for by the group picker, once its move went through.
  const { pathname, search, hash } = location;
  const wanted = (location.state as { household?: string } | null)?.household;
  useEffect(() => {
    if (!wanted) return;
    switchTo(wanted);
    // Done: Back to this page won't switch again.
    void navigate({ pathname, search, hash }, { replace: true, state: null });
  }, [wanted, pathname, search, hash, switchTo, navigate]);

  // A forced move (the group on screen went away), once it has landed: its mark comes off the history, so Back to this
  // page later asks before typed input is left, as any move does.
  const forced = !!(location.state as Partial<typeof FORCED_MOVE> | null)?.forced;
  useEffect(() => {
    if (forced) void navigate({ pathname, search, hash }, { replace: true, state: null });
  }, [forced, pathname, search, hash, navigate]);

  // The group each page of the history was shown in, by the history entry.
  const shownIn = useRef(new Map<string, string>());
  useEffect(() => {
    if (!shownIn.current.has(location.key)) shownIn.current.set(location.key, current.id);
  }, [location.key, current.id]);
  const recorded = shownIn.current.get(location.key);
  // The group this page was shown in is gone (left or deleted on this very page, or the person was removed) while the
  // page is a section's start: it simply shows the group on screen now, as it is. Nothing to restore, nothing to
  // rebuild: what is typed on it stays, and a download on it goes on.
  const gone = recorded !== undefined && !households.some((household) => household.id === recorded);
  const start = sectionOf(location.pathname) === location.pathname;
  // Back or Forward to a page of another group: that group first; the page waits for it.
  const elsewhere = !wanted && recorded !== undefined && recorded !== current.id && !(gone && start);
  useEffect(() => {
    if (gone && start && recorded !== current.id) shownIn.current.set(location.key, current.id);
  }, [gone, start, recorded, current.id, location.key]);
  const restoring = useRef(false);
  useEffect(() => {
    if (!elsewhere || !recorded) return;
    if (households.some((household) => household.id === recorded)) {
      restoring.current = true;
      switchTo(recorded);
    } else {
      // Not in that group any more: the section's start, in this one.
      shownIn.current.set(location.key, current.id);
      void navigate(sectionOf(location.pathname), { replace: true, state: FORCED_MOVE });
    }
  }, [elsewhere, recorded, households, current.id, location.key, location.pathname, switchTo, navigate]);

  // The group on screen changed without the picker (the person isn't in it any more): off to the section's start.
  // After a picked switch the page is there already; after Back to another group's page, it stays.
  const leavePage = useEffectEvent(() => {
    if (restoring.current) {
      restoring.current = false;
      return;
    }
    const section = sectionOf(location.pathname);
    if (section !== location.pathname) void navigate(section, { replace: true, state: FORCED_MOVE });
  });
  const shown = useRef(current.id);
  useEffect(() => {
    if (shown.current === current.id) return;
    shown.current = current.id;
    leavePage();
  }, [current.id]);

  // A file dropped outside a drop zone would replace the app in the browser.
  useEffect(() => {
    const ignore = (event: DragEvent) => {
      if (!event.dataTransfer || !Array.from(event.dataTransfer.types).includes('Files')) return;
      if (event.defaultPrevented) return;
      event.preventDefault();
      if (event.type === 'dragover') event.dataTransfer.dropEffect = 'none';
    };
    window.addEventListener('dragover', ignore);
    window.addEventListener('drop', ignore);
    return () => {
      window.removeEventListener('dragover', ignore);
      window.removeEventListener('drop', ignore);
    };
  }, []);

  return (
    <div
      className={`shell${menuOpen ? ' is-menu-open' : ''}`}
      onKeyDown={(event) => {
        if (event.key === 'Escape' && menuOpen) setMenuOpen(false);
      }}
    >
      <a className="skip-link" href="#main">
        {t.skipToContent}
      </a>
      <div className="topbar">
        <Brand />
        <button
          type="button"
          className="icon-button"
          aria-expanded={menuOpen}
          aria-controls="sidebar"
          aria-label={menuOpen ? t.menuClose : t.menuOpen}
          onClick={() => setMenuOpen((open) => !open)}
        >
          <Icon name={menuOpen ? 'close' : 'menu'} />
        </button>
      </div>
      <header className="sidebar" id="sidebar">
        <Brand />
        <nav className="nav" aria-label={t.navSections}>
          <NavLink to="/" end className="nav-link">
            <Icon name="home" />
            {t.navHome}
          </NavLink>
          <NavLink to="/today" className="nav-link">
            <Icon name="today" />
            {t.navToday}
          </NavLink>
          <NavLink to="/pets" className="nav-link">
            <Icon name="pets" />
            {t.navPets}
          </NavLink>
          <NavLink to="/visits" className="nav-link">
            <Icon name="event" />
            {t.navVisits}
          </NavLink>
          <NavLink to="/supplies" className="nav-link">
            <Icon name="inventory_2" />
            {t.navSupplies}
          </NavLink>
          <NavLink to="/settings" className="nav-link">
            <Icon name="settings" />
            {t.navSettings}
          </NavLink>
        </nav>
        <div className="sidebar-foot">
          <LiveStatus />
          <HouseholdPicker />
          <LanguagePicker />
          <Account />
        </div>
      </header>
      <div className="content">
        <OfflineBanner />
        <main id="main" className="main" tabIndex={-1}>
          <LeaveGuardProvider>{elsewhere ? <Loading /> : <Outlet />}</LeaveGuardProvider>
        </main>
      </div>
      <ScrollRestoration />
    </div>
  );
}

/** Whether others' changes show at once: only where live updates are set up at all. */
function LiveStatus() {
  const { live } = useSession();
  return live ? <LiveStatusBadge /> : null;
}

function Brand() {
  const { t } = useI18n();
  const { demo } = useSession();
  return (
    <Link to="/" className="brand">
      <img src={`${import.meta.env.BASE_URL}favicon.svg`} alt="" width={28} height={28} />
      <span className="brand-name">{t.appName}</span>
      {/* Made-up data: nobody takes it for their own. */}
      {demo && <span className="badge badge--demo">{t.demoBadge}</span>}
    </Link>
  );
}

/** The group on screen and the person's role there; a picker when they are in more than one. */
function HouseholdPicker() {
  const { t } = useI18n();
  const { current, households } = useHousehold();
  const switchHousehold = useSwitchHousehold();
  const nameOf = (household: typeof current) => householdName(t, household.name, household.role);

  return (
    <div className="sidebar-group">
      {households.length > 1 ? (
        <SelectField
          label={t.householdLabel}
          value={current.id}
          options={households.map((household) => ({
            value: household.id,
            label: `${nameOf(household)} · ${t.householdRole[household.role]}`,
          }))}
          onChange={switchHousehold}
        />
      ) : (
        <div className="household-card">
          <span className="field-label">{t.householdLabel}</span>
          <span className="household-name">{nameOf(current)}</span>
          <span className="muted small">{t.householdRole[current.role]}</span>
        </div>
      )}
      {current.role === 'Helper' && <p className="field-hint">{t.householdRoleHelperNote}</p>}
    </div>
  );
}

function LanguagePicker() {
  const { t, lang, choose } = useI18n();
  return (
    <fieldset className="sidebar-group">
      <legend className="field-label">{t.languageLabel}</legend>
      <div className="segmented">
        {LANGS.map((option) => (
          <label key={option} className="segmented-option" lang={option}>
            <input
              type="radio"
              name="language"
              value={option}
              checked={lang === option}
              onChange={() => choose(option)}
            />
            <span>{t.languageNames[option]}</span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}

function Account() {
  const { t } = useI18n();
  const { user, me, signOut } = useSession();
  const email = me.email ?? user.email;
  return (
    <div className="sidebar-group account">
      {email && (
        <p className="account-email">
          <span className="muted small">{t.signedInAs}</span>
          <span title={email}>{email}</span>
        </p>
      )}
      <button type="button" className="button button--secondary" onClick={() => signOut()}>
        <Icon name="logout" size={18} />
        {t.signOut}
      </button>
    </div>
  );
}
