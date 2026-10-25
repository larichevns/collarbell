// The weight over time, drawn by the app itself (the phone app's weight_chart.dart): the weights joined by a line, a
// weighing as a dot and a vet's weight as a hollow diamond (the shape tells them apart, not only the colour), the
// lowest and the highest weight on the side, the first and the last date below. Screen readers hear a summary; the
// history under the chart lists every value. The maths is in lib/weight.ts (chartLayout).
import { useLayoutEffect, useRef, useState } from 'react';
import { useI18n } from '../i18n/i18n';
import { weightValueLabel } from '../lib/labels';
import { chartLayout, DOT_RADIUS, type ChartInput } from '../lib/weight';

/** The plot's height, and the room its markers need around it. */
const HEIGHT = 160;
const DIAMOND = 5.5;
const RING = 2;
/** How far a diamond reaches past its centre, ring included: on a turned square a line moves the corner out by √2. */
const PAD = DIAMOND + (1 + RING) * Math.SQRT2;
/** The width before the box is measured (and in tests, which have no layout). */
const FALLBACK_WIDTH = 600;

export function WeightChart({ points, today }: { points: readonly ChartInput[]; today: string }) {
  const i18n = useI18n();
  const box = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(FALLBACK_WIDTH);

  useLayoutEffect(() => {
    const element = box.current;
    if (!element) return;
    const measure = () => {
      const measured = element.getBoundingClientRect().width;
      if (measured > 0) setWidth(Math.round(measured));
    };
    measure();
    if (typeof ResizeObserver === 'undefined') return;
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  const layout = chartLayout(points, { width, height: HEIGHT, pad: PAD });
  const first = points[0]!;
  const last = points.at(-1)!;
  // Both dates with the year when either isn't this year's.
  const thisYear = today.slice(0, 4);
  const withYear = layout.first.slice(0, 4) !== thisYear || layout.last.slice(0, 4) !== thisYear;
  const day = (date: string) => i18n.date(date, withYear ? 'medium' : 'dayMonth');
  const kg = (grams: number) => weightValueLabel(i18n, grams / 1000);
  const flat = layout.lowest === layout.highest;
  const summary = i18n.t.weightChartSummary(
    i18n.date(layout.first),
    i18n.date(layout.last),
    weightValueLabel(i18n, first.weightKg),
    weightValueLabel(i18n, last.weightKg),
    kg(layout.lowest),
    kg(layout.highest),
  );
  const hasVet = points.some((point) => point.vet);

  return (
    <figure className="weight-chart">
      <div className="weight-chart-body" role="img" aria-label={summary}>
        <div className="weight-chart-levels" aria-hidden="true" style={{ height: HEIGHT }}>
          <span style={{ top: layout.highY }}>{kg(layout.highest)}</span>
          {!flat && <span style={{ top: layout.lowY }}>{kg(layout.lowest)}</span>}
        </div>
        <div className="weight-chart-plot" ref={box}>
          <svg width={width} height={HEIGHT} viewBox={`0 0 ${width} ${HEIGHT}`} aria-hidden="true" focusable="false">
            <line className="weight-chart-grid" x1={0} x2={width} y1={layout.highY} y2={layout.highY} />
            {!flat && <line className="weight-chart-grid" x1={0} x2={width} y1={layout.lowY} y2={layout.lowY} />}
            <polyline
              className="weight-chart-line"
              points={layout.points.map((point) => `${round(point.x)},${round(point.y)}`).join(' ')}
            />
            {layout.points.map((point, index) =>
              point.marked ? <Marker key={index} x={point.x} y={point.y} vet={point.vet} /> : null,
            )}
          </svg>
        </div>
      </div>
      <div className="weight-chart-dates" aria-hidden="true">
        {layout.first !== layout.last && <span>{day(layout.first)}</span>}
        <span className="weight-chart-last">{day(layout.last)}</span>
      </div>
      {hasVet && (
        <div className="weight-chart-legend" aria-hidden="true">
          {points.some((point) => !point.vet) && (
            <span>
              <LegendMarker vet={false} />
              {i18n.t.weightSource.Weighing}
            </span>
          )}
          <span>
            <LegendMarker vet />
            {i18n.t.weightSource.CareRecord}
          </span>
        </div>
      )}
    </figure>
  );
}

const round = (value: number) => Math.round(value * 10) / 10;

/** A square turned 45° around (x, y), as SVG points. */
function diamond(x: number, y: number, radius: number): string {
  return [
    [x, y - radius],
    [x + radius, y],
    [x, y + radius],
    [x - radius, y],
  ]
    .map(([px, py]) => `${round(px!)},${round(py!)}`)
    .join(' ');
}

/** A weighing as a dot, a vet's weight as a hollow diamond, each in a ring of the card's colour. */
function Marker({ x, y, vet }: { x: number; y: number; vet: boolean }) {
  if (!vet) {
    return <circle className="weight-chart-dot" cx={round(x)} cy={round(y)} r={DOT_RADIUS + RING / 2} />;
  }
  return (
    <g className="weight-chart-vet">
      <polygon className="weight-chart-ring" points={diamond(x, y, PAD)} />
      <polygon className="weight-chart-diamond" points={diamond(x, y, DIAMOND)} />
    </g>
  );
}

function LegendMarker({ vet }: { vet: boolean }) {
  const size = Math.ceil(PAD * 2);
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden="true" focusable="false">
      <Marker x={size / 2} y={size / 2} vet={vet} />
    </svg>
  );
}
