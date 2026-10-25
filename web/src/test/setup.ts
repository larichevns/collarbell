// Before every test file: a clean page and storage after each test, and what jsdom lacks.
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

// React Router's ScrollRestoration scrolls the window; jsdom has no layout to scroll.
window.scrollTo = () => {};

// jsdom has <dialog> without its methods: open and close it the plain way.
HTMLDialogElement.prototype.showModal = function showModal(this: HTMLDialogElement) {
  this.setAttribute('open', '');
};
HTMLDialogElement.prototype.close = function close(this: HTMLDialogElement) {
  this.removeAttribute('open');
};

// jsdom has no object URLs, which show a picked photo before it is uploaded: one of its own for each, as a browser's.
let objectUrls = 0;
URL.createObjectURL = () => `blob:picked-photo-${(objectUrls += 1)}`;
URL.revokeObjectURL = () => {};

afterEach(() => {
  cleanup();
  window.localStorage.clear();
  // A theme picked in a test is no pick in the next.
  delete document.documentElement.dataset.theme;
});
