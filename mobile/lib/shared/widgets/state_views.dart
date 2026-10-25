import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../theme/collarbell_theme.dart';

/// Whether a list on screen shows its empty state: loaded and empty, and
/// not a failed reload (that shows the error, the old empty list still in
/// the value). The empty state has the add button then, so the one over or
/// above the list is left out; in every other state it stays reachable.
bool showsEmptyList(AsyncValue<List<Object?>> list) =>
    !(list.hasError && !list.isLoading) && (list.value?.isEmpty ?? false);

/// Whether a list's floating "Add" button shows: not before the list is
/// first known (it would show, then go for an empty list), and not while
/// the empty state has the button ([showsEmptyList]).
bool showsAddOverList(AsyncValue<List<Object?>> list) =>
    (list.hasValue || list.hasError) && !showsEmptyList(list);

/// A calm, neutral empty state: icon on a grey disc, title and one line.
class CbEmptyState extends StatelessWidget {
  const CbEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
  });

  final String title;
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final text = context.cbText;
    final icon = this.icon;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CbSpace.s6,
        vertical: CbSpace.s12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: CbSize.avatarLg,
              height: CbSize.avatarLg,
              decoration: BoxDecoration(
                color: cb.sunken,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: cb.inkMuted),
            ),
            const SizedBox(height: CbSpace.s4),
          ],
          Text(title, style: text.title, textAlign: TextAlign.center),
          const SizedBox(height: CbSpace.s2),
          Text(
            message,
            style: text.body.copyWith(color: cb.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// An error with a "Try again" button. Uses `danger` with an icon and words,
/// never colour alone.
class CbErrorState extends StatelessWidget {
  const CbErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.traceId,
  });

  final String message;
  final VoidCallback onRetry;

  /// Shown so a failed request can be found in the server logs.
  final String? traceId;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final text = context.cbText;
    final traceId = this.traceId;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CbSpace.s6,
        vertical: CbSpace.s12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.error_rounded, size: 32, color: cb.danger),
          const SizedBox(height: CbSpace.s3),
          Semantics(
            liveRegion: true,
            child: Text(message, style: text.body, textAlign: TextAlign.center),
          ),
          if (traceId != null) ...[
            const SizedBox(height: CbSpace.s2),
            SelectableText(
              context.l10n.errorReference(traceId),
              style: text.caption.copyWith(color: cb.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: CbSpace.s4),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Symbols.refresh_rounded),
            label: Text(context.l10n.commonTryAgain),
          ),
        ],
      ),
    );
  }
}

enum _LoadingShape { list, form, spinner }

/// While content loads: grey shapes where it will be, with a soft shimmer
/// moving across them (a skeleton), so the screen doesn't jump when the data
/// comes. A list shows rows, a form its fields. [CbLoadingState.spinner] is
/// for a wait that isn't content, e.g. the camera starting or AI reading.
class CbLoadingState extends StatefulWidget {
  /// Rows of a list: an avatar and two lines each.
  const CbLoadingState({super.key}) : _shape = _LoadingShape.list;

  /// The fields of a form that loads what it edits.
  const CbLoadingState.form({super.key}) : _shape = _LoadingShape.form;

  /// A spinner, where no content takes shape yet.
  const CbLoadingState.spinner({super.key}) : _shape = _LoadingShape.spinner;

  final _LoadingShape _shape;

  @override
  State<CbLoadingState> createState() => _CbLoadingStateState();
}

class _CbLoadingStateState extends State<CbLoadingState>
    with SingleTickerProviderStateMixin {
  late final _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No shimmer when the phone asks for less motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.commonLoading;
    if (widget._shape == _LoadingShape.spinner) {
      return Center(child: CircularProgressIndicator(semanticsLabel: label));
    }
    final c = context.cb;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        // The skeleton keeps its own height and is cut off where the space
        // ends: no overflow in a small space.
        child: UnconstrainedBox(
          constrainedAxis: Axis.horizontal,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: Padding(
            padding: const EdgeInsets.all(CbSpace.s4),
            child: AnimatedBuilder(
              animation: _shimmer,
              builder: (context, child) => ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) => LinearGradient(
                  colors: [c.line, c.sunken, c.line],
                  stops: const [0.35, 0.5, 0.65],
                  transform: _Slide(_shimmer.value),
                ).createShader(bounds),
                child: child,
              ),
              child: widget._shape == _LoadingShape.form
                  ? const _FormShapes()
                  : const _ListShapes(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Moves the shimmer's gradient from left of the shapes to right of them.
class _Slide extends GradientTransform {
  const _Slide(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
}

/// A grey block; the shimmer paints over it.
class _Block extends StatelessWidget {
  const _Block({
    this.width,
    this.widthFactor,
    required this.height,
    this.radius = CbRadius.sm,
  });

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.cb.line,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return widthFactor == null
        ? block
        : FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: widthFactor,
            child: block,
          );
  }
}

class _ListShapes extends StatelessWidget {
  const _ListShapes();

  static const rows = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CbSpace.s3),
            child: Row(
              children: [
                const _Block(width: 40, height: 40, radius: 20),
                const SizedBox(width: CbSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rows of different lengths look like real ones.
                      _Block(widthFactor: row.isEven ? 0.7 : 0.55, height: 14),
                      const SizedBox(height: CbSpace.s2),
                      _Block(widthFactor: row.isEven ? 0.4 : 0.5, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FormShapes extends StatelessWidget {
  const _FormShapes();

  static const fields = 5;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var field = 0; field < fields; field++) ...[
          _Block(widthFactor: field.isEven ? 0.3 : 0.4, height: 12),
          const SizedBox(height: CbSpace.s2),
          const _Block(widthFactor: 1, height: 48, radius: CbRadius.md),
          const SizedBox(height: CbSpace.s5),
        ],
      ],
    );
  }
}
