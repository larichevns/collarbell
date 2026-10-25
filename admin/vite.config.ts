// How the admin is built, served while developing, and tested.
//
//   npm run dev        the admin with the real sign-in; /api/ goes to the server (CB_API, default: the public address)
//   npm run dev:mock   the admin with test data and a pretend sign-in: no server, no Firebase (src/mock/)
//   npm run build      dist/, served by the web container under /admin/ (deploy/web.Dockerfile, deploy/nginx.conf)
//   npm test           the tests (Vitest, jsdom)
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  // The admin lives at https://<address>/admin/.
  base: '/admin/',
  plugins: [react()],
  server: {
    port: 5181,
    proxy: {
      '/api/': {
        target: process.env.CB_API ?? 'https://collarbell.example.com',
        changeOrigin: true,
      },
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['src/test/setup.ts'],
    // Dates in the tests are checked in one fixed time zone (UTC+3 all year), whatever the computer's.
    env: { TZ: 'Europe/Moscow' },
  },
});
