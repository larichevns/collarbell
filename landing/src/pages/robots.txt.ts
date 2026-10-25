// robots.txt: while the site lives on the temporary hostname (INDEXABLE = false in src/site.ts), search engines
// are asked to stay away from everything. The same host serves the API and file links; they are never indexed.
import type { APIRoute } from 'astro';
import { INDEXABLE } from '../site';

export const GET: APIRoute = () => {
  const rules = INDEXABLE
    ? ['User-agent: *', 'Disallow: /api/', 'Disallow: /collarbell/', 'Disallow: /health']
    : ['User-agent: *', 'Disallow: /'];
  return new Response(`${rules.join('\n')}\n`, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
};
