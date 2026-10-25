import 'pet.dart';

/// What is wrong with a microchip or tattoo code.
enum IdentifierProblem {
  empty,

  /// Longer than [IdentifierRules.maxRawLength] as typed.
  tooLong,

  /// An ISO chip that doesn't have exactly 15 digits.
  isoLength,

  /// An ISO number starting with 999: those belong to test chips.
  isoTestChip,

  /// Neither 10 characters 0–9/A–F nor 9 digits (AVID).
  legacyFormat,

  /// More than [IdentifierRules.maxTattooLength] letters and digits.
  tattooLength,

  /// The same code is already in the list.
  duplicate,
}

/// The API's rules for microchip and tattoo codes (spec, appendix A.7),
/// repeated here so the form can explain a mistake before saving. The server
/// checks the same rules.
abstract final class IdentifierRules {
  static const maxIdentifiers = 5;
  static const maxRawLength = 40;
  static const maxTattooLength = 20;

  static final _separators = RegExp(r'[\s\-.*]');
  static final _isoChip = RegExp(r'^[0-9]{15}$');
  static final _legacyChip = RegExp(r'^(?:[0-9A-F]{10}|[0-9]{9})$');

  /// 15 digits in a row, not part of a longer number.
  static final _isoChipInText = RegExp(r'(?<![0-9])[0-9]{15}(?![0-9])');

  /// Upper case without spaces, hyphens, dots and asterisks:
  /// `276 098-100.123*456` becomes `276098100123456`.
  static String normalize(String raw) =>
      raw.replaceAll(_separators, '').toUpperCase();

  /// The problem with [raw] for [type], or null when the code fits.
  /// [otherCodes] are the normalised codes of the other identifiers.
  static IdentifierProblem? check(
    IdentifierType type,
    String raw, {
    Iterable<String> otherCodes = const [],
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return IdentifierProblem.empty;
    if (trimmed.length > maxRawLength) return IdentifierProblem.tooLong;

    final code = normalize(trimmed);
    final problem = switch (type) {
      IdentifierType.isoChip when !_isoChip.hasMatch(code) =>
        IdentifierProblem.isoLength,
      IdentifierType.isoChip when code.startsWith('999') =>
        IdentifierProblem.isoTestChip,
      IdentifierType.legacyChip when !_legacyChip.hasMatch(code) =>
        IdentifierProblem.legacyFormat,
      IdentifierType.tattoo
          when code.isEmpty || code.length > maxTattooLength =>
        IdentifierProblem.tattooLength,
      _ => null,
    };
    if (problem != null) return problem;
    return otherCodes.contains(code) ? IdentifierProblem.duplicate : null;
  }

  /// The microchip number in a scanned code, or null when it isn't a chip's
  /// (a product barcode, a website). 15 digits in a row anywhere in the
  /// code are an ISO chip, so `ISO 643094100000001` is one too, and so is
  /// `643 094 100 000 001`: the digits count as they are, or without the
  /// spaces, hyphens and dots between them. Otherwise the whole code must be
  /// a non-ISO chip's: 10 characters 0–9 and A–F, or 9 digits.
  static ({IdentifierType type, String code})? chipFromBarcode(String code) {
    final normalized = normalize(code);
    final iso =
        _isoChipInText.firstMatch(code) ??
        _isoChipInText.firstMatch(normalized);
    if (iso != null) return (type: IdentifierType.isoChip, code: iso[0]!);
    if (_legacyChip.hasMatch(normalized)) {
      return (type: IdentifierType.legacyChip, code: normalized);
    }
    return null;
  }

  /// An ISO number in groups of three, as printed in passports:
  /// `276 098 100 123 456`. Other codes stay as they are.
  static String display(IdentifierType type, String code) {
    if (type != IdentifierType.isoChip || !_isoChip.hasMatch(code)) return code;
    return [
      for (var i = 0; i < code.length; i += 3) code.substring(i, i + 3),
    ].join(' ');
  }
}
