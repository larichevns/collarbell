// Before every test file: a clean page after each test, and what jsdom lacks.
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

// React Router's ScrollRestoration scrolls the window; jsdom has no layout to scroll.
window.scrollTo = () => {};

afterEach(() => {
  cleanup();
});
