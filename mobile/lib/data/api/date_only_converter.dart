import 'package:json_annotation/json_annotation.dart';

/// Reads and writes the API's calendar dates (`format: date`, e.g.
/// `2021-04-03`).
///
/// The generated models type these fields as `DateTime?`, and the default
/// `DateTime` serialisation sends a full timestamp, which the server rejects
/// for a date. swagger_parser applies this converter to every `DateTime?`
/// field (see `field_parsers` in swagger_parser.yaml). The only nullable
/// timestamp in the contract, `PassportResponse.updatedAt`, is never sent
/// back, and reading accepts both forms.
class DateOnlyConverter implements JsonConverter<DateTime?, String?> {
  const DateOnlyConverter();

  @override
  DateTime? fromJson(String? json) =>
      json == null ? null : DateTime.parse(json);

  @override
  String? toJson(DateTime? date) => date == null ? null : formatDateOnly(date);
}

/// [DateOnlyConverter] for required dates (`DateTime` without `?`), such as
/// a plan's `nextDueOn` or a record's `performedOn`.
///
/// swagger_parser can only pick a converter by Dart type, so this one is
/// also applied to the required timestamps of responses (`createdAt`,
/// `expiresAt`...). That is harmless: reading accepts both forms, exactly
/// like the default code, and responses are never sent back.
class RequiredDateOnlyConverter implements JsonConverter<DateTime, String> {
  const RequiredDateOnlyConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json);

  @override
  String toJson(DateTime date) => formatDateOnly(date);
}

/// `2021-04-03`: the calendar date of [date], whatever its time part.
String formatDateOnly(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
}
