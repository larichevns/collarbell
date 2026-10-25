// How the app is built, served while developing, and tested.
//
//   npm run dev       the app with the real sign-in; /api/, /hubs/ (live updates) and /health go to the server (CB_API,
//                     default: the public address)
//   npm run dev:mock  the demo: made-up data in English or Russian, a pretend sign-in and server (src/mock/)
//   npm run build     dist/, served by the web container under /app/ (deploy/web.Dockerfile, deploy/nginx.conf)
//   npm test          the tests (Vitest, jsdom)
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

const api = {
  target: process.env.CB_API ?? 'https://collarbell.example.com',
  changeOrigin: true,
};

export default defineConfig({
  // The app lives at https://<address>/app/.
  base: '/app/',
  plugins: [react()],
  build: {
    rolldownOptions: {
      output: {
        // React with its router, and Firebase, change far less often than the app: in files of their own they stay in
        // the browser's cache across deploys. So do the texts (both languages) across the deploys that fix code only;
        // they are also a quarter of the app's own code, which keeps the rest under Vite's 500 kB warning.
        codeSplitting: {
          groups: [
            { name: 'react', test: /node_modules[\\/](react|react-dom|react-router|scheduler)[\\/]/ },
            { name: 'firebase', test: /node_modules[\\/]@?firebase[\\/]/ },
            { name: 'texts', test: /[\\/]src[\\/]i18n[\\/](en|ru)\.ts$/ },
          ],
        },
      },
    },
  },
  server: {
    port: 5182,
    // /health tells the offline banner that the server is back; /hubs/ is the live updates' WebSocket.
    proxy: { '/api/': api, '/hubs/': { ...api, ws: true }, '/health': api },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['src/test/setup.ts'],
    // Dates in the tests are checked in one fixed time zone (UTC+3 all year), whatever the computer's.
    env: { TZ: 'Europe/Moscow' },
  },
});
