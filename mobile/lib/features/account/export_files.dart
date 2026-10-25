import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'account.dart';

/// The largest export "Save" takes. file_picker hands the whole file to the
/// system's "save as" screen through the platform channel: on Android it
/// ends up in one Java byte array, which a phone with little memory may not
/// have room for. A bigger export leaves by Share.
const exportSaveLimit = 25 * 1000 * 1000;

/// Where the downloaded export waits on the phone, and how it leaves: to a
/// place the person picks, or through the share sheet. Tests replace it and
/// touch no files.
abstract interface class ExportFiles {
  /// An empty folder for a new download. The copies an earlier export left
  /// go first ([clearAll]).
  Future<Directory> freshFolder();

  /// Lets the person pick where to keep [file] (Downloads, Files, Drive)
  /// and puts it there. False when they cancel.
  Future<bool> save(ExportFile file);

  /// Opens the share sheet with [file].
  Future<void> share(ExportFile file);

  /// Deletes the download: the sheet closed. A copy the share sheet made
  /// stays for now, as another app may still be reading it.
  Future<void> clear();

  /// Deletes every copy of an export on the phone: the download (a whole one,
  /// or what a download cut off midway left) and the copies Share and Save
  /// made. When a new export starts, and on sign-out.
  Future<void> clearAll();
}

/// [ExportFiles] in the app's temporary folder, with file_picker's "save
/// as" and share_plus.
class DeviceExportFiles implements ExportFiles {
  static const _zip = 'application/zip';

  /// How an export's file is named (`collarbell-export-2026-10-06.zip`):
  /// only such copies are deleted outside our own folder.
  static final _exportName = RegExp(r'^collarbell-export-.*\.zip$');

  Future<Directory> _temp() => getTemporaryDirectory();

  Future<Directory> _folder() async =>
      Directory('${(await _temp()).path}/data_export');

  @override
  Future<Directory> freshFolder() async {
    await clearAll();
    return (await _folder()).create(recursive: true);
  }

  @override
  Future<bool> save(ExportFile file) async {
    final saved = await FilePicker.saveFile(
      fileName: file.name,
      bytes: await File(file.path).readAsBytes(),
      mimeType: _zip,
    );
    // On the iPhone file_picker writes the bytes to NSTemporaryDirectory()
    // and exports that copy; it stays there, saved or not. Dart's system
    // temp is that folder on iOS (TMPDIR). Not tried yet: iOS isn't built.
    if (Platform.isIOS) {
      await _delete(File('${Directory.systemTemp.path}/${file.name}'));
    }
    return saved != null;
  }

  /// Shared under its own name: the download gave it the server's. On
  /// Android share_plus first copies it whole into `<cache>/share_plus/`
  /// (free space needed) and keeps that copy, as a receiving app may still
  /// be reading it: until its next share, or until [clearAll].
  @override
  Future<void> share(ExportFile file) => SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: _zip)]),
  );

  @override
  Future<void> clear() async {
    final folder = await _folder();
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  @override
  Future<void> clearAll() async {
    await clear();
    final temp = await _temp();
    // share_plus's copy (Android: the app's cache folder).
    await _deleteExports(Directory('${temp.path}/share_plus'));
    // file_picker's copy on the iPhone (see [save]).
    if (Platform.isIOS) await _deleteExports(Directory.systemTemp);
  }

  /// Deletes the export copies in [folder] (only those, by name).
  Future<void> _deleteExports(Directory folder) async {
    if (!await folder.exists()) return;
    await for (final entry in folder.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File && _exportName.hasMatch(name)) await _delete(entry);
    }
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      debugPrint('An export copy was not deleted: $error');
    }
  }
}

final exportFilesProvider = Provider<ExportFiles>((ref) => DeviceExportFiles());
