import 'package:flutter/material.dart';

import '../../theme/collarbell_theme.dart';

/// A white card with the `line` border from the theme and the soft
/// `shadow-card` token shadow, which Material elevation cannot express.
class CbCard extends StatelessWidget {
  const CbCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CbSpace.s4),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CbRadius.lg),
        boxShadow: context.cbShadows.card,
      ),
      child: Card(
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
