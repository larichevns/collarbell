// Astro settings for Collarbell's public site. Site-wide values (address, contact, indexing) live in
// src/site.ts; this file only says how the site is built.
import { defineConfig, passthroughImageService } from 'astro/config';
import { SITE_URL } from './src/site.ts';

export default defineConfig({
  // Canonical and hreflang links are built from this address.
  site: SITE_URL,
  // Plain files for nginx: every page is a folder with index.html (/privacy/index.html), 404.html at the root.
  output: 'static',
  trailingSlash: 'always',
  build: {
    format: 'directory',
  },
  // English at /, Russian at /ru/.
  i18n: {
    locales: ['en', 'ru'],
    defaultLocale: 'en',
    routing: {
      prefixDefaultLocale: false,
    },
  },
  // Screenshots are already WebP in the right sizes (tool/make-assets.sh): nothing to convert at build time.
  image: {
    service: passthroughImageService(),
  },
  // No dev toolbar: the site has no JavaScript of its own.
  devToolbar: {
    enabled: false,
  },
});
