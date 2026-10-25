// The start: styles and the theme picked here, the sign-in and the network (real, or the demo's in npm run dev:mock),
// the router under /app.
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter } from 'react-router';
import { App } from './App';
import { BASENAME, routes } from './routes';
import { createServices } from './services';
import { applyTheme, storedTheme } from './theme';
import './styles/fonts.css';
import './styles/tokens.css';
import './styles/theme.css';
import './styles/app.css';

applyTheme(storedTheme());

// Made once: signing out and in again keeps the address the person was on.
const router = createBrowserRouter(routes, { basename: BASENAME });

void createServices().then((services) => {
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <App services={services} router={router} />
    </StrictMode>,
  );
});
