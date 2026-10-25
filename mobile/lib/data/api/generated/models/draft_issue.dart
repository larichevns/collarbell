// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum DraftIssue {
  @JsonValue('Unreadable')
  unreadable('Unreadable'),
  @JsonValue('Ambiguous')
  ambiguous('Ambiguous'),
  @JsonValue('InFuture')
  inFuture('InFuture'),
  @JsonValue('EndsBeforeStart')
  endsBeforeStart('EndsBeforeStart'),
  @JsonValue('InvalidFormat')
  invalidFormat('InvalidFormat'),
  @JsonValue('AlreadySaved')
  alreadySaved('AlreadySaved'),
  @JsonValue('Repeated')
  repeated('Repeated'),
  @JsonValue('DiffersFromSaved')
  differsFromSaved('DiffersFromSaved'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const DraftIssue(this.json);

  factory DraftIssue.fromJson(dynamic json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final dynamic json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<DraftIssue> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
