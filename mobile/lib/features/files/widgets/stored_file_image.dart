import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/collarbell_theme.dart';
import '../stored_file.dart';

/// Makes the image provider for a stored file's link. cached_network_image
/// keeps the image on disk under [cacheKey] (the file id), so the signed
/// link, which changes on every response, doesn't download it again.
///
/// Widget tests override this provider: the disk cache needs plugins that
/// tests don't have.
final storedImageProvider =
    Provider<ImageProvider Function(String url, String cacheKey)>(
      (ref) =>
          (url, cacheKey) =>
              CachedNetworkImageProvider(url, cacheKey: cacheKey),
    );

/// A stored photo: its 480 px thumbnail or the full-size picture.
class StoredFileImage extends ConsumerWidget {
  const StoredFileImage({
    super.key,
    required this.file,
    this.fullSize = false,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final StoredFile file;

  /// The full picture instead of the thumbnail (used by the page viewer).
  final bool fullSize;
  final BoxFit fit;

  /// Shown while the picture loads and when it can't be loaded; a grey box
  /// by default.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailUrl = file.thumbnailUrl;
    final useThumbnail = !fullSize && thumbnailUrl != null;
    final image = ref.watch(storedImageProvider)(
      useThumbnail ? thumbnailUrl : file.url,
      useThumbnail ? file.thumbnailCacheKey : file.cacheKey,
    );
    return Image(
      image: image,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          frame == null && !wasSynchronouslyLoaded
          ? placeholder ?? ColoredBox(color: context.cb.sunken)
          : child,
      errorBuilder: (context, error, stackTrace) =>
          placeholder ??
          const FilePlaceholder(icon: Symbols.broken_image_rounded),
    );
  }
}

/// A grey tile with an icon, for PDFs and pictures that can't be shown.
class FilePlaceholder extends StatelessWidget {
  const FilePlaceholder({super.key, required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    final label = this.label;
    return ColoredBox(
      color: cb.sunken,
      child: Padding(
        padding: const EdgeInsets.all(CbSpace.s2),
        // Shrinks to fit small thumbnails, e.g. in the documents list.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: cb.inkMuted),
              if (label != null) ...[
                const SizedBox(height: CbSpace.s1),
                Text(
                  label,
                  style: context.cbText.caption.copyWith(color: cb.inkMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A page tile that fills its box: the photo's thumbnail, or a PDF icon.
class PageTile extends StatelessWidget {
  const PageTile({
    super.key,
    required this.file,
    this.onTap,
    this.semanticLabel,
  });

  final StoredFile file;
  final VoidCallback? onTap;

  /// Read by screen readers, e.g. "Page 2".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: file.isPdf
          ? FilePlaceholder(
              icon: Symbols.picture_as_pdf_rounded,
              label: context.l10n.filePdf,
            )
          : StoredFileImage(file: file),
    );
  }
}

/// A tile for a picked file that isn't uploaded yet; fills its box.
class PickedMediaTile extends StatelessWidget {
  const PickedMediaTile({super.key, required this.media, this.semanticLabel});

  final PickedMedia media;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      semanticLabel: semanticLabel,
      child: media.isPdf
          ? FilePlaceholder(
              icon: Symbols.picture_as_pdf_rounded,
              label: media.name,
            )
          : Image.file(
              File(media.path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const FilePlaceholder(icon: Symbols.image_rounded),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.child, this.onTap, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CbRadius.sm);
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: context.cb.line),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(child: child),
                if (onTap != null)
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(onTap: onTap),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
