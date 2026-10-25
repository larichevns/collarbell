import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_exception.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../theme/collarbell_theme.dart';
import 'account.dart';
import 'account_labels.dart';
import 'account_repository.dart';
import 'export_files.dart';

/// "Download my data": a sheet that downloads the ZIP of everything of the
/// person's into a temporary file, shows how much has come (the server
/// doesn't say the total) with "Cancel", then offers to save or share it.
/// However the sheet closes, the download stops and the file is deleted.
Future<void> showDataExport(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const _DataExportSheet(),
);

class _DataExportSheet extends ConsumerStatefulWidget {
  const _DataExportSheet();

  @override
  ConsumerState<_DataExportSheet> createState() => _DataExportSheetState();
}

class _DataExportSheetState extends ConsumerState<_DataExportSheet> {
  late final ExportFiles _files;
  final _cancel = CancelToken();

  /// Bytes downloaded so far.
  var _received = 0;
  ExportFile? _file;
  Object? _error;

  /// Saving or sharing: the buttons wait.
  var _busy = false;
  var _saved = false;
  var _saveFailed = false;
  var _shareFailed = false;

  @override
  void initState() {
    super.initState();
    // Kept for dispose, where ref can't be used any more.
    _files = ref.read(exportFilesProvider);
    unawaited(_download());
  }

  @override
  void dispose() {
    // Closed while downloading: the download stops, and what came goes.
    _cancel.cancel();
    unawaited(
      _files.clear().catchError(
        (Object error) => debugPrint('The export was not deleted: $error'),
      ),
    );
    super.dispose();
  }

  Future<void> _download() async {
    final repository = ref.read(accountRepositoryProvider);
    try {
      final folder = await _files.freshFolder();
      if (!mounted) return;
      final file = await repository.downloadExport(
        folder,
        onReceived: (received) {
          if (mounted) setState(() => _received = received);
        },
        cancelToken: _cancel,
      );
      if (mounted) setState(() => _file = file);
    } catch (error) {
      if (_cancel.isCancelled) return;
      debugPrint('Downloading the data failed: $error');
      if (mounted) setState(() => _error = error);
    }
  }

  void _again() {
    setState(() {
      _error = null;
      _received = 0;
    });
    unawaited(_download());
  }

  Future<void> _save(ExportFile file) async {
    setState(() {
      _busy = true;
      _saved = false;
      _saveFailed = false;
      _shareFailed = false;
    });
    try {
      final saved = await _files.save(file);
      if (mounted) setState(() => _saved = saved);
    } catch (error) {
      // E.g. no app on the phone to pick a place with.
      debugPrint('Saving the data failed: $error');
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(ExportFile file) async {
    setState(() {
      _busy = true;
      _saved = false;
      _saveFailed = false;
      _shareFailed = false;
    });
    try {
      await _files.share(file);
    } catch (error) {
      // For a big export the only way out: it has to say so.
      debugPrint('Sharing the data failed: $error');
      if (mounted) setState(() => _shareFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final file = _file;
    final error = _error;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          0,
          CbSpace.s4,
          CbSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.dataExportTitle, style: text.title),
            ),
            const SizedBox(height: CbSpace.s1),
            Text(
              l10n.dataExportHelper,
              style: text.bodySm.copyWith(color: cb.inkMuted),
            ),
            const SizedBox(height: CbSpace.s4),
            if (error != null)
              ..._failed(context, error)
            else if (file != null)
              ..._ready(context, file)
            else
              ..._downloading(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _downloading(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    return [
      Text(
        _received == 0
            ? l10n.dataExportPreparing
            : l10n.dataExportProgress(fileSizeLabel(l10n, _received)),
        style: context.cbText.body,
      ),
      const SizedBox(height: CbSpace.s3),
      // No total is known: a bar that moves without filling up.
      ClipRRect(
        borderRadius: BorderRadius.circular(CbRadius.full),
        child: LinearProgressIndicator(
          minHeight: CbSpace.s2,
          backgroundColor: cb.sunken,
          semanticsLabel: l10n.dataExportTitle,
        ),
      ),
      const SizedBox(height: CbSpace.s4),
      OutlinedButton(onPressed: _close, child: Text(l10n.commonCancel)),
    ];
  }

  List<Widget> _ready(BuildContext context, ExportFile file) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final canSave = file.bytes <= exportSaveLimit;
    final share = canSave
        ? OutlinedButton.icon(
            onPressed: _busy ? null : () => _share(file),
            icon: const Icon(Symbols.share_rounded),
            label: Text(l10n.dataExportShare),
          )
        : FilledButton.icon(
            onPressed: _busy ? null : () => _share(file),
            icon: const Icon(Symbols.share_rounded),
            label: Text(l10n.dataExportShare),
          );
    return [
      Semantics(
        liveRegion: true,
        child: Text(
          l10n.dataExportReady(fileSizeLabel(l10n, file.bytes)),
          style: text.body,
        ),
      ),
      const SizedBox(height: CbSpace.s1),
      Text(
        l10n.dataExportKeepSafe,
        style: text.bodySm.copyWith(color: cb.inkMuted),
      ),
      const SizedBox(height: CbSpace.s4),
      if (canSave) ...[
        FilledButton.icon(
          onPressed: _busy ? null : () => _save(file),
          icon: const Icon(Symbols.save_alt_rounded),
          label: Text(l10n.commonSave),
        ),
        const SizedBox(height: CbSpace.s2),
      ],
      share,
      if (!canSave) ...[
        const SizedBox(height: CbSpace.s2),
        Text(
          l10n.dataExportTooLarge,
          style: text.bodySm.copyWith(color: cb.inkMuted),
        ),
      ],
      if (_saved) ...[
        const SizedBox(height: CbSpace.s3),
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.dataExportSaved,
            textAlign: TextAlign.center,
            style: text.bodySm.copyWith(color: cb.inkMuted),
          ),
        ),
      ],
      if (_saveFailed) ...[
        const SizedBox(height: CbSpace.s3),
        CbNotice.error(message: l10n.dataExportSaveFailed),
      ],
      if (_shareFailed) ...[
        const SizedBox(height: CbSpace.s3),
        CbNotice.error(message: l10n.dataExportShareFailed),
      ],
      const SizedBox(height: CbSpace.s2),
      TextButton(onPressed: _close, child: Text(l10n.commonClose)),
    ];
  }

  List<Widget> _failed(BuildContext context, Object error) {
    final l10n = context.l10n;
    // A few downloads an hour: trying again now would be refused too.
    final tooOften =
        error is ApiException && error.kind == ApiErrorKind.tooManyRequests;
    return [
      CbNotice.error(message: dataExportErrorMessage(error, l10n)),
      const SizedBox(height: CbSpace.s4),
      if (!tooOften) ...[
        OutlinedButton.icon(
          onPressed: _again,
          icon: const Icon(Symbols.refresh_rounded),
          label: Text(l10n.commonTryAgain),
        ),
        const SizedBox(height: CbSpace.s2),
      ],
      TextButton(onPressed: _close, child: Text(l10n.commonClose)),
    ];
  }
}
