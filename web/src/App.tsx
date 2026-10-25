// The app as a whole: the cache of the server's data, the language, short messages, the session, the pages.
// main.tsx starts it in the browser; the tests start it with a pretend sign-in and server (src/test/).
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';
import { RouterProvider, type DataRouter } from 'react-router';
import { ApiError } from './api/client';
import { ToastProvider } from './components/Toasts';
import { I18nProvider } from './i18n/i18n';
import { SessionGate, type Services } from './session';

function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        // No answer, or a server error, gets one more try; an answer that says something (404, 403) is final.
        retry: (failures, error) =>
          failures < 1 && error instanceof ApiError && (error.status === 0 || error.status >= 500),
      },
    },
  });
}

export function App({
  services,
  router,
  queryClient,
}: {
  services: Services;
  router: DataRouter;
  queryClient?: QueryClient;
}) {
  const [client] = useState(() => queryClient ?? createQueryClient());
  return (
    <QueryClientProvider client={client}>
      <I18nProvider>
        <ToastProvider>
          <SessionGate services={services}>
            <RouterProvider router={router} />
          </SessionGate>
        </ToastProvider>
      </I18nProvider>
    </QueryClientProvider>
  );
}
