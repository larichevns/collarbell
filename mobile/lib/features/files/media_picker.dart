import 'dart:io' show Directory, File;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'stored_file.dart';

/// Takes photos and picks files from the phone.
///
/// Screens use it through [mediaPickerProvider], so tests can replace it
/// with a fake that returns files without opening the camera.
abstract interface class MediaPicker {
  /// A photo from the camera, or null when the user cancels.
  Future<PickedMedia?> takePhoto();

  /// One photo from the library, or null when the user cancels.
  Future<PickedMedia?> pickPhoto();

  /// Several photos from the library, at most [limit] when it is given;
  /// empty when the user cancels.
  Future<List<PickedMedia>> pickPhotos({int? limit});

  /// A PDF from Files, or null when the user cancels.
  Future<PickedMedia?> pickPdf();

  /// Pages from the document scanner, at most [maxPages]: the camera finds
  /// the page's edges, straightens it and takes page after page. Null when
  /// the user cancels. The pages are as large as the camera took them:
  /// [prepareScans] makes them ready to upload.
  ///
  /// Throws [ScannerUnavailableException] where the scanner can't run (a
  /// simulator, a phone without it), and a [PlatformException] when the
  /// camera can't be opened (no access).
  Future<List<PickedMedia>?> scanPages({required int maxPages});

  /// The scanned [pages] as JPEG of at most 2048 px, upright, like photos
  /// from the library; the scanner's own files are deleted. A page that
  /// can't be shrunk goes as it is.
  Future<List<PickedMedia>> prepareScans(List<PickedMedia> pages);

  /// Deletes picked files from the phone once they aren't needed any more
  /// (uploaded, or dropped): scanned pages are personal documents. A file
  /// that is gone already is no error.
  Future<void> deletePicked(List<PickedMedia> media);
}

/// The document scanner can't run on this phone, e.g. in a simulator.
/// Photos from the library do the same job.
class ScannerUnavailableException implements Exception {
  const ScannerUnavailableException(this.reason);

  /// For developers: what the scanner said.
  final String reason;

  @override
  String toString() => 'ScannerUnavailableException($reason)';
}

/// [MediaPicker] over image_picker (camera, photo library), file_picker
/// (PDFs) and cunning_document_scanner (VisionKit on iOS, the ML Kit
/// document scanner on Android).
class DeviceMediaPicker implements MediaPicker {
  DeviceMediaPicker([ImagePicker? imagePicker])
    : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  // The server keeps photos at most 2048 px as JPEG, so a smaller, already
  // compressed upload loses nothing and uploads faster.
  static const _maxSide = 2048.0;
  static const _jpegQuality = 85;

  @override
  Future<PickedMedia?> takePhoto() async {
    final photo = await _images.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _jpegQuality,
      requestFullMetadata: false,
    );
    return photo == null ? null : _fromXFile(photo);
  }

  @override
  Future<PickedMedia?> pickPhoto() async {
    final photo = await _images.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _jpegQuality,
      requestFullMetadata: false,
    );
    return photo == null ? null : _fromXFile(photo);
  }

  @override
  Future<List<PickedMedia>> pickPhotos({int? limit}) async {
    final photos = await _images.pickMultiImage(
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _jpegQuality,
      limit: limit,
      requestFullMetadata: false,
    );
    return [for (final photo in photos) _fromXFile(photo)];
  }

  @override
  Future<PickedMedia?> pickPdf() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = file?.path;
    if (file == null || path == null) return null;
    return PickedMedia(path: path, name: file.name);
  }

  @override
  Future<List<PickedMedia>?> scanPages({required int maxPages}) async {
    // The scanner keeps its pages in its own folder (on Android not a cache
    // the system empties). Pages of an earlier scan are uploaded by now, so
    // they go before a new scan writes more.
    try {
      await CunningDocumentScanner.cleanCache();
    } catch (_) {
      // Only tidying up: the scan works all the same.
    }

    final List<String>? paths;
    try {
      paths = await CunningDocumentScanner.getPictures(
        noOfPages: maxPages,
        // JPEG, like the other photos: a PNG page is several times larger
        // and could pass the 15 MB upload limit. The server shrinks pages
        // to 2048 px itself. Neither scanner writes the location into them.
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          jpgCompressionQuality: _jpegQuality / 100,
        ),
      );
    } on CunningDocumentScannerException catch (error) {
      if (error.code == 'permission_denied') {
        throw PlatformException(
          code: 'permission_denied',
          message: error.message,
        );
      }
      // UNAVAILABLE (a simulator), NO_ACTIVITY and the like.
      throw ScannerUnavailableException('${error.code}: ${error.message}');
    } on MissingPluginException catch (error) {
      throw ScannerUnavailableException('$error');
    }
    if (paths == null) return null;
    return [
      for (final path in paths)
        PickedMedia(path: path, name: path.split('/').last),
    ];
  }

  @override
  Future<List<PickedMedia>> prepareScans(List<PickedMedia> pages) async => [
    for (final page in pages) await _shrink(page),
  ];

  @override
  Future<void> deletePicked(List<PickedMedia> media) async {
    for (final item in media) {
      await _deleteQuietly(item.path);
    }
  }

  /// The scanned [page] as a JPEG of at most [_maxSide] px on its long side
  /// (quality [_jpegQuality], upright, without EXIF), like photos from the
  /// library: a camera-size page is several megabytes, and the server keeps
  /// 2048 px anyway. The scanner's own file is deleted. When shrinking
  /// fails, the page goes as it is.
  static Future<PickedMedia> _shrink(PickedMedia page) async {
    final path = page.path;
    try {
      final (width, height) = await _imageSize(path);
      final scale = math.max(1.0, math.max(width, height) / _maxSide);
      final shrunk = await FlutterImageCompress.compressAndGetFile(
        path,
        '${Directory.systemTemp.path}/'
        'collarbell-page-${DateTime.now().microsecondsSinceEpoch}.jpg',
        // The plugin calls its bounds "min": it scales the image down until
        // one side meets its bound. Bounds in the image's own proportions
        // make the long side the one that ends at 2048 px.
        minWidth: (width / scale).floor(),
        minHeight: (height / scale).floor(),
        quality: _jpegQuality,
      );
      if (shrunk == null) return page;
      await _deleteQuietly(path);
      return PickedMedia(path: shrunk.path, name: shrunk.name);
    } catch (error) {
      debugPrint('Shrinking a scanned page failed; it goes as it is: $error');
      return page;
    }
  }

  /// Width and height of the image at [path], read from its header.
  static Future<(int, int)> _imageSize(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = (descriptor.width, descriptor.height);
      descriptor.dispose();
      return size;
    } finally {
      buffer.dispose();
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // Gone already, or never written: nothing to clean up.
    }
  }

  static PickedMedia _fromXFile(XFile file) =>
      PickedMedia(path: file.path, name: file.name);
}

final mediaPickerProvider = Provider<MediaPicker>((ref) => DeviceMediaPicker());
