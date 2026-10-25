// A page only those who change things use: a form. Helpers, who see everything and only mark, get a word instead of
// a form whose "Save" the server would refuse at the end (a link, or an address typed in).
import type { ReactNode } from 'react';
import { Link } from 'react-router';
import { useHousehold } from '../household/household';
import { useI18n } from '../i18n/i18n';
import { Icon } from './Icon';
import { Notice, PageHead } from './ui';

export function ForEditors({ children }: { children: ReactNode }) {
  const { t } = useI18n();
  const { permissions } = useHousehold();
  if (permissions.canEdit) return <>{children}</>;
  return (
    <>
      <PageHead title={t.helperFormTitle} />
      <Notice tone="warning">
        <p>{t.helperFormBody}</p>
        <Link to="/" className="button button--secondary">
          <Icon name="home" size={18} />
          {t.notFoundLink}
        </Link>
      </Notice>
    </>
  );
}
