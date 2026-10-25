import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/collarbell_theme.dart';
import '../stored_file.dart';
import 'stored_file_image.dart';

/// Pages as tiles, three in a row. Lives inside a scrolling list, so the
/// grid itself doesn't scroll.
class PageGrid extends StatelessWidget {
  const PageGrid({super.key, required this.pages, required this.onTap});

  final List<StoredFile> pages;
  final ValueChanged<StoredFile> onTap;

  static const columns = 3;

  /// Width to height of a tile: portrait, like a page, so a photographed
  /// page isn't cut to a square.
  static const tileAspectRatio = 3 / 4;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      childAspectRatio: tileAspectRatio,
      mainAxisSpacing: CbSpace.s2,
      crossAxisSpacing: CbSpace.s2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < pages.length; i++)
          PageTile(
            file: pages[i],
            semanticLabel: context.l10n.pageNumber(i + 1),
            onTap: () => onTap(pages[i]),
          ),
      ],
    );
  }
}
