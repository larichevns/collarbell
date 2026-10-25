import 'package:dio/dio.dart' show MultipartFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/generated/export.dart' as dto;
import 'stored_file.dart';

abstract interface class FilesRepository {
  /// Uploads a photo (JPEG, PNG or WebP) or a PDF of up to 15 MB. Throws
  /// ApiException: [ApiErrorKind.payloadTooLarge] or
  /// [ApiErrorKind.unsupportedMediaType] when the server refuses the file.
  ///
  /// The file must be attached to a pet or a document next, or the server
  /// deletes it after a day.
  Future<StoredFile> upload(PickedMedia media);

  /// Fresh download links for a file.
  Future<StoredFile> getLink(String fileId);
}

/// [FilesRepository] over the generated API client.
class ApiFilesRepository implements FilesRepository {
  ApiFilesRepository(this._client);

  final ApiClient _client;

  @override
  Future<StoredFile> upload(PickedMedia media) async {
    // The server decides the type from the file's first bytes, so the part
    // needs no content type.
    final file = await MultipartFile.fromFile(media.path, filename: media.name);
    final link = await _client.send((api) => api.files.uploadFile(file: file));
    return storedFileFromDto(link);
  }

  @override
  Future<StoredFile> getLink(String fileId) async {
    final link = await _client.send((api) => api.files.getFileLink(id: fileId));
    return storedFileFromDto(link);
  }
}

/// Maps the API representation of a file.
StoredFile storedFileFromDto(dto.FileLink link) => StoredFile(
  id: link.id,
  contentType: link.contentType,
  sizeBytes: link.sizeBytes,
  width: link.width,
  height: link.height,
  url: link.url,
  thumbnailUrl: link.thumbnailUrl,
  expiresAt: link.expiresAt,
);

final filesRepositoryProvider = Provider<FilesRepository>(
  (ref) => ApiFilesRepository(ref.watch(apiClientProvider)),
);

/// A fresh link for one file, fetched when a full-size viewer opens: links
/// in lists may have expired by the time the user taps a page.
final fileLinkProvider = FutureProvider.autoDispose.family<StoredFile, String>(
  (ref, fileId) => ref.watch(filesRepositoryProvider).getLink(fileId),
);

/// Uploads the files one after another. [onProgress] gets the number of
/// files done so far, for an "Uploading 2 of 3" line.
Future<List<StoredFile>> uploadAll(
  FilesRepository files,
  List<PickedMedia> media, {
  void Function(int done)? onProgress,
}) async {
  final uploaded = <StoredFile>[];
  for (final item in media) {
    uploaded.add(await files.upload(item));
    onProgress?.call(uploaded.length);
  }
  return uploaded;
}
