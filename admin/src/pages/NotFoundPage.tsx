import { Link } from 'react-router';
import { PageHead } from '../components/ui';

export function NotFoundPage() {
  return (
    <>
      <PageHead title="Такой страницы нет" />
      <p>
        <Link to="/">На обзор</Link>
      </p>
    </>
  );
}
