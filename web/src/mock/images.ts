// The pictures of the demo (npm run dev:mock): pets' photos, the pages of a paper passport, a lab report, a vaccine's
// sticker, drawn here as SVG and shown from data: addresses, and a small PDF made on the spot (a blob: address). All
// made up; nothing is downloaded.
import type { Lang } from '../i18n/lang';

/** An SVG as an address an <img> can show. */
const svg = (width: number, height: number, body: string) =>
  `data:image/svg+xml,${encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}">${body}</svg>`,
  )}`;

const escape = (text: string) => text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const FONT = "font-family='Helvetica, Arial, sans-serif'";

/** A cat's face on the palette's cream. */
export function catPhoto(): string {
  return svg(
    400,
    400,
    `<rect width="400" height="400" fill="#fffae6"/>
     <circle cx="200" cy="230" r="120" fill="#8e9aaf"/>
     <path d="M98 170 L120 60 L185 125 Z" fill="#8e9aaf"/><path d="M302 170 L280 60 L215 125 Z" fill="#8e9aaf"/>
     <path d="M118 150 L128 92 L165 128 Z" fill="#f2b8c6"/><path d="M282 150 L272 92 L235 128 Z" fill="#f2b8c6"/>
     <ellipse cx="155" cy="215" rx="20" ry="26" fill="#f4e04d"/><ellipse cx="245" cy="215" rx="20" ry="26" fill="#f4e04d"/>
     <ellipse cx="155" cy="218" rx="7" ry="20" fill="#222"/><ellipse cx="245" cy="218" rx="7" ry="20" fill="#222"/>
     <path d="M188 262 L212 262 L200 276 Z" fill="#d97a8b"/>
     <path d="M200 276 Q185 296 168 288 M200 276 Q215 296 232 288" stroke="#444" stroke-width="4" fill="none"/>
     <path d="M120 270 L60 258 M120 282 L58 292 M280 270 L340 258 M280 282 L342 292" stroke="#555" stroke-width="3"/>`,
  );
}

/** A dog's face on the palette's light blue. */
export function dogPhoto(): string {
  return svg(
    400,
    400,
    `<rect width="400" height="400" fill="#e6ebfa"/>
     <ellipse cx="200" cy="215" rx="115" ry="125" fill="#d9a65f"/>
     <ellipse cx="92" cy="200" rx="40" ry="85" fill="#a8743a" transform="rotate(18 92 200)"/>
     <ellipse cx="308" cy="200" rx="40" ry="85" fill="#a8743a" transform="rotate(-18 308 200)"/>
     <ellipse cx="200" cy="285" rx="62" ry="48" fill="#f0d3a3"/>
     <circle cx="160" cy="200" r="14" fill="#2b1d12"/><circle cx="240" cy="200" r="14" fill="#2b1d12"/>
     <circle cx="165" cy="195" r="4" fill="#fff"/><circle cx="245" cy="195" r="4" fill="#fff"/>
     <ellipse cx="200" cy="262" rx="26" ry="18" fill="#2b1d12"/>
     <path d="M200 280 L200 300 M200 300 Q180 318 165 306 M200 300 Q220 318 235 306" stroke="#2b1d12" stroke-width="4" fill="none"/>
     <path d="M188 318 Q200 345 212 318 Z" fill="#e86f7b"/>`,
  );
}

/** The cover of an EU pet passport: blue, with the ring of stars. */
export function passportCover(lang: Lang): string {
  const stars = Array.from({ length: 12 }, (_, index) => {
    const angle = (index / 12) * Math.PI * 2;
    return `<circle cx="${310 + 70 * Math.cos(angle)}" cy="${300 + 70 * Math.sin(angle)}" r="7" fill="#ffd200"/>`;
  }).join('');
  const title = lang === 'ru' ? 'ПАСПОРТ ЖИВОТНОГО' : 'PET PASSPORT';
  return svg(
    620,
    877,
    `<rect width="620" height="877" fill="#1d3f8f"/>
     <rect x="24" y="24" width="572" height="829" fill="none" stroke="#8aa4e0" stroke-width="2"/>
     <text x="310" y="150" ${FONT} font-size="30" fill="#fff" text-anchor="middle">EUROPEAN UNION</text>
     ${stars}
     <text x="310" y="520" ${FONT} font-size="40" font-weight="bold" fill="#fff" text-anchor="middle">${title}</text>
     <text x="310" y="570" ${FONT} font-size="22" fill="#c9d6f5" text-anchor="middle">Regulation (EU) No 576/2013</text>`,
  );
}

/** A page of a form: a title, then labels with handwritten-blue values on lines. */
export function formPage(title: string, rows: readonly [string, string][], stamp?: string): string {
  const lines = rows
    .map(
      ([label, value], index) => `
     <text x="48" y="${170 + index * 62}" ${FONT} font-size="15" fill="#666">${escape(label)}</text>
     <line x1="48" x2="572" y1="${200 + index * 62}" y2="${200 + index * 62}" stroke="#bbb"/>
     <text x="60" y="${193 + index * 62}" font-family="'Segoe Script', 'Bradley Hand', cursive" font-size="22" fill="#1f3c88">${escape(value)}</text>`,
    )
    .join('');
  const seal = stamp
    ? `<g transform="rotate(-12 460 760)"><circle cx="460" cy="760" r="62" fill="none" stroke="#7b3fa0" stroke-width="4"/>
       <text x="460" y="768" ${FONT} font-size="17" fill="#7b3fa0" text-anchor="middle">${escape(stamp)}</text></g>`
    : '';
  return svg(
    620,
    877,
    `<rect width="620" height="877" fill="#fbfaf4"/>
     <rect x="20" y="20" width="580" height="837" fill="none" stroke="#d6d3c4"/>
     <text x="48" y="96" ${FONT} font-size="26" font-weight="bold" fill="#222">${escape(title)}</text>
     <line x1="48" x2="572" y1="116" y2="116" stroke="#222" stroke-width="2"/>
     ${lines}${seal}`,
  );
}

/** A lab report: a table of results with their reference ranges. */
export function labPage(title: string, header: readonly string[], rows: readonly string[][]): string {
  const cells = (values: readonly string[], y: number, bold = false) =>
    values
      .map(
        (value, column) =>
          `<text x="${48 + column * 175}" y="${y}" ${FONT} font-size="16" ${bold ? 'font-weight="bold"' : ''} fill="#222">${escape(value)}</text>`,
      )
      .join('');
  return svg(
    620,
    877,
    `<rect width="620" height="877" fill="#fff"/>
     <rect x="0" y="0" width="620" height="70" fill="#e7f0ec"/>
     <text x="48" y="45" ${FONT} font-size="22" font-weight="bold" fill="#066849">VetLab</text>
     <text x="48" y="130" ${FONT} font-size="24" font-weight="bold" fill="#222">${escape(title)}</text>
     ${cells(header, 190, true)}
     <line x1="48" x2="572" y1="202" y2="202" stroke="#222"/>
     ${rows.map((row, index) => cells(row, 240 + index * 40)).join('')}`,
  );
}

/** A vaccine's sticker, photographed on the page: the product, its batch and expiry. */
export function stickerPhoto(product: string, batch: string, expiry: string): string {
  const bars = Array.from({ length: 34 }, (_, index) => {
    const width = index % 3 === 0 ? 4 : 2;
    return `<rect x="${70 + index * 8}" y="200" width="${width}" height="70" fill="#111"/>`;
  }).join('');
  return svg(
    480,
    360,
    `<rect width="480" height="360" fill="#e9e4d4"/>
     <rect x="40" y="60" width="400" height="240" rx="12" fill="#fff" stroke="#999"/>
     <text x="70" y="115" ${FONT} font-size="30" font-weight="bold" fill="#c8233f">${escape(product)}</text>
     <text x="70" y="155" ${FONT} font-size="20" fill="#333">Lot ${escape(batch)}</text>
     <text x="70" y="185" ${FONT} font-size="20" fill="#333">EXP ${escape(expiry)}</text>
     ${bars}`,
  );
}

/**
 * A one-page PDF with lines of text (Latin letters: the standard Helvetica of PDF has no Cyrillic), as a blob:
 * address. Built by hand: the objects, then the table of where each starts.
 */
export function pdfFile(lines: readonly string[]): { url: string; size: number } {
  const text = lines
    .map(
      (line, index) =>
        `BT /F1 ${index === 0 ? 20 : 12} Tf 64 ${770 - index * 26} Td (${line.replace(/[()\\]/g, '')}) Tj ET`,
    )
    .join('\n');
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    `<< /Length ${text.length} >>\nstream\n${text}\nendstream`,
  ];
  let body = '%PDF-1.4\n';
  const offsets: number[] = [];
  objects.forEach((object, index) => {
    offsets.push(body.length);
    body += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = body.length;
  body += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  body += offsets.map((offset) => `${String(offset).padStart(10, '0')} 00000 n \n`).join('');
  body += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  const blob = new Blob([body], { type: 'application/pdf' });
  return { url: URL.createObjectURL(blob), size: blob.size };
}
