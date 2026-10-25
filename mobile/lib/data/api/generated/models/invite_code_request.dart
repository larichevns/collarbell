// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'invite_code_request.g.dart';

@JsonSerializable()
class InviteCodeRequest {
  const InviteCodeRequest({
    required this.code,
  });
  
  factory InviteCodeRequest.fromJson(Map<String, Object?> json) => _$InviteCodeRequestFromJson(json);
  
  final String? code;

  Map<String, Object?> toJson() => _$InviteCodeRequestToJson(this);
}
