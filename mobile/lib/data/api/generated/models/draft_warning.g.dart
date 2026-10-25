// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_warning.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DraftWarning _$DraftWarningFromJson(Map<String, dynamic> json) => DraftWarning(
  field: json['field'] as String,
  issue: DraftIssue.fromJson(json['issue']),
);

Map<String, dynamic> _$DraftWarningToJson(DraftWarning instance) =>
    <String, dynamic>{
      'field': instance.field,
      'issue': _$DraftIssueEnumMap[instance.issue]!,
    };

const _$DraftIssueEnumMap = {
  DraftIssue.unreadable: 'Unreadable',
  DraftIssue.ambiguous: 'Ambiguous',
  DraftIssue.inFuture: 'InFuture',
  DraftIssue.endsBeforeStart: 'EndsBeforeStart',
  DraftIssue.invalidFormat: 'InvalidFormat',
  DraftIssue.alreadySaved: 'AlreadySaved',
  DraftIssue.repeated: 'Repeated',
  DraftIssue.differsFromSaved: 'DiffersFromSaved',
  DraftIssue.$unknown: r'$unknown',
};
