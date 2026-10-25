import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../theme/collarbell_theme.dart';
import 'files_repository.dart';
import 'stored_file.dart';
import 'widgets/stored_file_image.dart';

/// Opens [pages] (photos) full screen, above the tabs, at [initialIndex].
/// With [onDelete] the viewer offers "Delete page"; it calls [onDelete] and
/// closes itself when no pages are left.
Future<void> openPageViewer(
  BuildContext context, {
  required List<StoredFile> pages,
  int initialIndex = 0,
  Future<void> Function(StoredFile page)? onDelete,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PageViewerScreen(
        pages: pages,
        initialIndex: initialIndex,
        onDelete: onDelete,
      ),
    ),
  );
}

/// Swipe between pages, pinch to zoom. Each page asks for a fresh full-size
/// link when it opens; until it arrives, the thumbnail is shown.
class PageViewerScreen extends StatefulWidget {
  const PageViewerScreen({
    super.key,
    required this.pages,
    this.initialIndex = 0,
    this.onDelete,
  });

  final List<StoredFile> pages;
  final int initialIndex;
  final Future<void> Function(StoredFile page)? onDelete;

  @override
  State<PageViewerScreen> createState() => _PageViewerScreenState();
}

class _PageViewerScreenState extends State<PageViewerScreen> {
  late final List<StoredFile> _pages = [...widget.pages];
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  var _deleting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _deleteCurrent() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _deleting) return;
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.pageDeleteTitle,
      message: l10n.pageDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !mounted) return;

    final page = _pages[_index];
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      await onDelete(page);
      if (!mounted) return;
      setState(() {
        _pages.removeAt(_index);
        if (_index >= _pages.length) _index = _pages.length - 1;
      });
      if (_pages.isEmpty) Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Deleting the page failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessageFor(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    return Scaffold(
      // Photos read best on a dark background.
      backgroundColor: cb.inverseSurface,
      appBar: AppBar(
        backgroundColor: cb.inverseSurface,
        foregroundColor: cb.onInverse,
        iconTheme: IconThemeData(color: cb.onInverse),
        actionsIconTheme: IconThemeData(color: cb.onInverse),
        titleTextStyle: context.cbText.subtitle.copyWith(color: cb.onInverse),
        title: _pages.isEmpty
            ? null
            : Text(l10n.pageOf(_index + 1, _pages.length)),
        actions: [
          if (widget.onDelete != null)
            _deleting
                ? Padding(
                    padding: const EdgeInsets.all(CbSpace.s3),
                    child: SizedBox.square(
                      dimension: CbSpace.s5,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cb.onInverse,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: l10n.pageDelete,
                    icon: Icon(Symbols.delete_rounded, color: cb.onInverse),
                    onPressed: _deleteCurrent,
                  ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _pages.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) => _ZoomablePage(page: _pages[index]),
      ),
    );
  }
}

/// One page: the fresh full-size picture, zoomable.
class _ZoomablePage extends ConsumerWidget {
  const _ZoomablePage({required this.page});

  final StoredFile page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(fileLinkProvider(page.id));
    final fresh = link.value;
    return InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            StoredFileImage(
              file: fresh ?? page,
              fullSize: fresh != null,
              fit: BoxFit.contain,
            ),
            if (link.isLoading)
              CircularProgressIndicator(color: context.cb.onInverse),
            if (link.hasError && fresh == null)
              _LinkError(
                onRetry: () => ref.invalidate(fileLinkProvider(page.id)),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinkError extends StatelessWidget {
  const _LinkError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cb = context.cb;
    return Container(
      padding: const EdgeInsets.all(CbSpace.s4),
      decoration: BoxDecoration(
        color: cb.surface,
        borderRadius: BorderRadius.circular(CbRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.pageLoadFailed, style: context.cbText.body),
          const SizedBox(height: CbSpace.s2),
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
