// The start: styles, the sign-in and the network (real, or test data in npm run dev:mock), the router under /admin.
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter, RouterProvider } from 'react-router';
import { BASENAME, routes } from './routes';
import { createServices } from './services';
import { SessionGate } from './session';
import './styles/fonts.css';
import './styles/tokens.css';
import './styles/app.css';

// Made once: signing out and in again keeps the address the owner was on.
const router = createBrowserRouter(routes, { basename: BASENAME });

void createServices().then((services) => {
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <SessionGate services={services}>
        <RouterProvider router={router} />
      </SessionGate>
    </StrictMode>,
  );
});
