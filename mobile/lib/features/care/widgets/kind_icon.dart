import 'package:flutter/material.dart';

import '../../../theme/collarbell_theme.dart';
import '../care.dart';
import '../care_labels.dart';

/// The kind of care as an icon on a grey disc, at the start of a row.
/// Decorative: the row's text says what it is.
class KindIcon extends StatelessWidget {
  const KindIcon({super.key, required this.kind});

  final CareKind kind;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return ExcludeSemantics(
      child: Container(
        width: CbSize.avatarMd,
        height: CbSize.avatarMd,
        decoration: BoxDecoration(color: cb.sunken, shape: BoxShape.circle),
        child: Icon(careKindIcon(kind), color: cb.inkMuted, size: 22),
      ),
    );
  }
}
