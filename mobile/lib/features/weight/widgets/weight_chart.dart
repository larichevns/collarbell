import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/collarbell_theme.dart';
import '../weight.dart';
import '../weight_labels.dart';

/// The radius of a weighing's dot.
const _dotRadius = 4.0;

/// Half the width of a vet's diamond: about the area of the dot.
const _diamondRadius = 5.5;

/// The ring of the card's colour around a marker: it keeps the marker
/// apart from the line and from a marker it overlaps.
const _ring = 2.0;

/// How far a diamond reaches past its centre, outline and ring included:
/// on a turned square, a line of width w moves the corner out by w × √2.
const _diamondReach = _diamondRadius + (1 + _ring) * math.sqrt2;

/// The weight over time: the weights joined by a line, a weighing as a dot
/// and a vet's weight as a hollow diamond; the lowest and the highest weight
/// on the side, the first and the last date at the bottom. Screen readers
/// hear a summary instead, and the history under the chart lists every
/// value.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.points, required this.today});

  /// Oldest first; at least two.
  final List<WeightEntry> points;

  /// Dates of this year are shown without the year.
  final DateTime today;

  /// The height of the plot itself, without the dates under it.
  static const plotHeight = 128.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final labelStyle = context.cbText.caption.copyWith(color: cb.inkMuted);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final grams = [for (final point in points) point.grams];
    final lowest = grams.reduce(math.min);
    final highest = grams.reduce(math.max);
    final first = points.first.measuredOn;
    final last = points.last.measuredOn;
    // Both dates with the year when either isn't this year's.
    final withYear = first.year != today.year || last.year != today.year;

    // The band of the dates grows with the text size, so the plot keeps its
    // height and the dates are never cut off.
    final line = TextPainter(
      text: TextSpan(text: '0', style: labelStyle),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final dateBand = line.height + CbSpace.s2;
    line.dispose();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: l10n.weightChartSummary(
            l10n.dateMedium(first),
            l10n.dateMedium(last),
            weightValueLabel(l10n, points.first.weightKg),
            weightValueLabel(l10n, points.last.weightKg),
            weightValueLabel(l10n, lowest / 1000),
            weightValueLabel(l10n, highest / 1000),
          ),
          child: SizedBox(
            height: plotHeight + 2 * _diamondReach + dateBand,
            child: CustomPaint(
              painter: _ChartPainter(
                points: [
                  for (final point in points)
                    (
                      day: _daysBetween(first, point.measuredOn),
                      grams: point.grams,
                      vet: point.isVet,
                    ),
                ],
                lowest: lowest,
                highest: highest,
                lowestLabel: weightValueLabel(l10n, lowest / 1000),
                highestLabel: weightValueLabel(l10n, highest / 1000),
                firstDate: weightDayLabel(l10n, first, withYear: withYear),
                lastDate: weightDayLabel(l10n, last, withYear: withYear),
                colors: (line: cb.primary, surface: cb.surface, grid: cb.line),
                labelStyle: labelStyle,
                textScaler: textScaler,
                textDirection: textDirection,
              ),
            ),
          ),
        ),
        // Which marker is which, when a vet's weight is among them. The
        // history under the chart says it to screen readers already.
        if (points.any((point) => point.isVet)) ...[
          const SizedBox(height: CbSpace.s3),
          ExcludeSemantics(
            child: Wrap(
              spacing: CbSpace.s4,
              runSpacing: CbSpace.s1,
              children: [
                if (points.any((point) => !point.isVet))
                  _LegendItem(vet: false, label: l10n.weightSourceWeighing),
                _LegendItem(vet: true, label: l10n.weightSourceVet),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Calendar days from [from] to [to], counted on the dates: a day with a
  /// clock change has 23 or 25 hours.
  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

/// One marker of the chart and what it stands for.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.vet, required this.label});

  final bool vet;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size.square(2 * _diamondReach),
          painter: _MarkerPainter(
            vet: vet,
            colors: (line: cb.primary, surface: cb.surface, grid: cb.line),
          ),
        ),
        const SizedBox(width: CbSpace.s1),
        // Wraps on a narrow phone with large text instead of running off it.
        Flexible(
          child: Text(
            label,
            style: context.cbText.caption.copyWith(color: cb.inkMuted),
          ),
        ),
      ],
    );
  }
}

/// A weight on the chart: days after the first one, its grams, and whether
/// a vet noted it.
typedef _ChartPoint = ({int day, int grams, bool vet});

/// The line and its markers, the gridlines and the axis labels.
typedef _ChartColors = ({Color line, Color surface, Color grid});

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.lowest,
    required this.highest,
    required this.lowestLabel,
    required this.highestLabel,
    required this.firstDate,
    required this.lastDate,
    required this.colors,
    required this.labelStyle,
    required this.textScaler,
    required this.textDirection,
  });

  /// Oldest first.
  final List<_ChartPoint> points;
  final int lowest;
  final int highest;
  final String lowestLabel;
  final String highestLabel;
  final String firstDate;
  final String lastDate;
  final _ChartColors colors;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    TextPainter label(String text) => TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();

    // All the same weight: one level, in the middle.
    final flat = lowest == highest;
    final high = label(highestLabel);
    final low = flat ? null : label(lowestLabel);
    final from = label(firstDate);
    final to = label(lastDate);
    final dateBand = math.max(from.height, to.height) + CbSpace.s2;
    // The weights' labels sit left of the plot, right-aligned.
    final gutter = math.max(high.width, low?.width ?? 0) + CbSpace.s2;
    final plot = Rect.fromLTRB(
      gutter + _diamondReach,
      math.max(_diamondReach, high.height / 2),
      size.width - _diamondReach,
      size.height - dateBand - math.max(_diamondReach, (low?.height ?? 0) / 2),
    );

    double y(int grams) => flat
        ? plot.center.dy
        : plot.bottom - plot.height * (grams - lowest) / (highest - lowest);
    final lastDay = points.last.day;
    Offset at(_ChartPoint point) => Offset(
      lastDay == 0
          ? plot.center.dx
          : plot.left + plot.width * point.day / lastDay,
      y(point.grams),
    );

    // The highest and the lowest weight: a hairline across the plot and the
    // value beside it.
    final grid = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    for (final (grams, text) in [
      (highest, high),
      if (low != null) (lowest, low),
    ]) {
      final level = y(grams);
      canvas.drawLine(Offset(gutter, level), Offset(size.width, level), grid);
      text.paint(
        canvas,
        Offset(gutter - CbSpace.s2 - text.width, level - text.height / 2),
      );
    }

    final path = Path();
    for (final (index, point) in points.indexed) {
      final offset = at(point);
      if (index == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Dots closer than two of their widths would merge into a band: then
    // the line carries the weighings, and only the latest keeps its dot. A
    // vet's weight is always marked.
    final dense = plot.width / (points.length - 1) < 4 * _dotRadius;
    for (final (index, point) in points.indexed) {
      if (point.vet || !dense || index == points.length - 1) {
        _paintMarker(canvas, at(point), vet: point.vet, colors: colors);
      }
    }

    // The first and the last date; only the last when both don't fit.
    final top = size.height - dateBand + CbSpace.s2;
    to.paint(canvas, Offset(size.width - to.width, top));
    if (firstDate != lastDate &&
        from.width + to.width + CbSpace.s4 <= size.width - gutter) {
      from.paint(canvas, Offset(gutter, top));
    }

    for (final text in [high, ?low, from, to]) {
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      !listEquals(points, old.points) ||
      lowest != old.lowest ||
      highest != old.highest ||
      lowestLabel != old.lowestLabel ||
      highestLabel != old.highestLabel ||
      firstDate != old.firstDate ||
      lastDate != old.lastDate ||
      colors != old.colors ||
      labelStyle != old.labelStyle ||
      textScaler != old.textScaler ||
      textDirection != old.textDirection;
}

/// A weighing as a dot, a vet's weight as a hollow diamond, each in a ring
/// of the card's colour. The shapes tell them apart without colour.
void _paintMarker(
  Canvas canvas,
  Offset center, {
  required bool vet,
  required _ChartColors colors,
}) {
  final surface = Paint()..color = colors.surface;
  if (!vet) {
    canvas.drawCircle(center, _dotRadius + _ring, surface);
    canvas.drawCircle(center, _dotRadius, Paint()..color = colors.line);
    return;
  }
  // A square turned 45°.
  Path diamond(double radius) => Path()
    ..moveTo(center.dx, center.dy - radius)
    ..lineTo(center.dx + radius, center.dy)
    ..lineTo(center.dx, center.dy + radius)
    ..lineTo(center.dx - radius, center.dy)
    ..close();
  canvas.drawPath(diamond(_diamondReach), surface);
  canvas.drawPath(
    diamond(_diamondRadius),
    Paint()
      ..color = colors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
}

/// One marker in the middle of its box, for the legend.
class _MarkerPainter extends CustomPainter {
  _MarkerPainter({required this.vet, required this.colors});

  final bool vet;
  final _ChartColors colors;

  @override
  void paint(Canvas canvas, Size size) =>
      _paintMarker(canvas, size.center(Offset.zero), vet: vet, colors: colors);

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      vet != old.vet || colors != old.colors;
}
