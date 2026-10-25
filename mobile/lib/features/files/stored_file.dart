import 'package:flutter/foundation.dart';

/// A photo or PDF stored by the API, with download links that expire.
///
/// The links are signed and change on every response, so images are cached
/// by the file id ([cacheKey]), never by the link.
@immutable
class StoredFile {
  const StoredFile({
    required this.id,
    required this.contentType,
    required this.sizeBytes,
    required this.url,
    required this.expiresAt,
    this.width,
    this.height,
    this.thumbnailUrl,
  });

  final String id;

  /// `image/jpeg` for photos (the server re-encodes them) or
  /// `application/pdf`.
  final String contentType;
  final int sizeBytes;

  /// Pixel size; photos only.
  final int? width;
  final int? height;

  /// The full-size file, valid until [expiresAt].
  final String url;

  /// A 480 px JPEG preview; photos only.
  final String? thumbnailUrl;
  final DateTime expiresAt;

  bool get isPdf => contentType == 'application/pdf';

  /// Cache keys for cached_network_image.
  String get cacheKey => id;
  String get thumbnailCacheKey => '$id-thumb';

  @override
  bool operator ==(Object other) =>
      other is StoredFile &&
      other.id == id &&
      other.contentType == contentType &&
      other.sizeBytes == sizeBytes &&
      other.width == width &&
      other.height == height &&
      other.url == url &&
      other.thumbnailUrl == thumbnailUrl &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(
    id,
    contentType,
    sizeBytes,
    width,
    height,
    url,
    thumbnailUrl,
    expiresAt,
  );

  @override
  String toString() => 'StoredFile($id, $contentType)';
}

/// A photo or PDF on the phone that the user picked and that isn't uploaded
/// yet.
@immutable
class PickedMedia {
  const PickedMedia({required this.path, required this.name});

  /// Absolute path of a local file.
  final String path;

  /// File name with extension, e.g. `IMG_0042.jpg`.
  final String name;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');

  @override
  bool operator ==(Object other) =>
      other is PickedMedia && other.path == path && other.name == name;

  @override
  int get hashCode => Object.hash(path, name);

  @override
  String toString() => 'PickedMedia($name)';
}
