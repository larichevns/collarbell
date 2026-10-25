// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/file_link.dart';
import '../models/i_form_file.dart';

part 'files_client.g.dart';

@RestApi()
abstract class FilesClient {
  factory FilesClient(Dio dio, {String? baseUrl}) = _FilesClient;

  /// Upload a photo (JPEG, PNG, WebP) or a PDF, up to 15 MB.
  ///
  /// Photos are stored as JPEG without metadata, at most 2048 px on the long side, with a thumbnail. Attach the file to a pet or a document next; files that are never attached are deleted after a day.
  @MultiPart()
  @POST('/api/v1/files')
  Future<FileLink> uploadFile({
    @Part(name: 'file') IFormFile? file,
  });

  /// Fresh download links for a file of the household.
  @GET('/api/v1/files/{id}/url')
  Future<FileLink> getFileLink({
    @Path('id') required String id,
  });
}
