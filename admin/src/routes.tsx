// The admin's addresses, under /admin/ (the router's basename):
//   /                    Обзор: the numbers of the service
//   /users?q=…           Люди: search by e-mail or name
//   /users/:id?at=…      Человек: profile, groups, phones, AI and the визор (at: open it around a moment)
//   /households/:id      Группа: members with roles, counts
//   /problems?hours=…    Проблемы: server errors, app errors and crashes
import { useParams, type RouteObject } from 'react-router';
import { Layout } from './components/Layout';
import { HouseholdPage } from './pages/HouseholdPage';
import { NotFoundPage } from './pages/NotFoundPage';
import { OverviewPage } from './pages/OverviewPage';
import { ProblemsPage } from './pages/ProblemsPage';
import { RouteError } from './pages/RouteError';
import { UserPage } from './pages/UserPage';
import { UsersPage } from './pages/UsersPage';

export const BASENAME = '/admin';

/** Another person or group: a fresh page, nothing carried over from the previous one. */
function UserRoute() {
  const { id = '' } = useParams();
  return <UserPage key={id} id={id} />;
}

function HouseholdRoute() {
  const { id = '' } = useParams();
  return <HouseholdPage key={id} id={id} />;
}

export const routes: RouteObject[] = [
  {
    element: <Layout />,
    errorElement: <RouteError />,
    children: [
      {
        // A page that breaks shows the error under the header.
        errorElement: <RouteError />,
        children: [
          { index: true, element: <OverviewPage /> },
          { path: 'users', element: <UsersPage /> },
          { path: 'users/:id', element: <UserRoute /> },
          { path: 'households/:id', element: <HouseholdRoute /> },
          { path: 'problems', element: <ProblemsPage /> },
          { path: '*', element: <NotFoundPage /> },
        ],
      },
    ],
  },
];
