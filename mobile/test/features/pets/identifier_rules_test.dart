import 'package:collarbell/features/pets/identifier_rules.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalize drops spaces, hyphens, dots and asterisks, upper-cases', () {
    expect(
      IdentifierRules.normalize(' 276 098-100.123*456 '),
      '276098100123456',
    );
    expect(IdentifierRules.normalize('ab-12'), 'AB12');
  });

  test('ISO chips have 15 digits and no 999 test prefix', () {
    expect(
      IdentifierRules.check(IdentifierType.isoChip, '276 098 100 123 456'),
      isNull,
    );
    expect(
      IdentifierRules.check(IdentifierType.isoChip, '27609810012345'),
      IdentifierProblem.isoLength,
    );
    expect(
      IdentifierRules.check(IdentifierType.isoChip, '27609810012345A'),
      IdentifierProblem.isoLength,
    );
    expect(
      IdentifierRules.check(IdentifierType.isoChip, '999000000000001'),
      IdentifierProblem.isoTestChip,
    );
  });

  test('legacy chips are 10 hex characters or 9 digits (AVID)', () {
    expect(
      IdentifierRules.check(IdentifierType.legacyChip, '0a1b2c3d4e'),
      isNull,
    );
    expect(
      IdentifierRules.check(IdentifierType.legacyChip, '123-456-789'),
      isNull,
    );
    expect(
      IdentifierRules.check(IdentifierType.legacyChip, '0A1B2C3D4G'),
      IdentifierProblem.legacyFormat,
    );
  });

  test('tattoos have 1 to 20 letters and digits; codes are required', () {
    expect(IdentifierRules.check(IdentifierType.tattoo, 'ABC 123'), isNull);
    expect(
      IdentifierRules.check(IdentifierType.tattoo, 'A' * 21),
      IdentifierProblem.tattooLength,
    );
    expect(
      IdentifierRules.check(IdentifierType.tattoo, '---'),
      IdentifierProblem.tattooLength,
    );
    expect(
      IdentifierRules.check(IdentifierType.tattoo, '  '),
      IdentifierProblem.empty,
    );
    expect(
      IdentifierRules.check(IdentifierType.tattoo, '1' * 41),
      IdentifierProblem.tooLong,
    );
  });

  test('the same code twice is a duplicate, however it is written', () {
    expect(
      IdentifierRules.check(
        IdentifierType.isoChip,
        '276-098-100-123-456',
        otherCodes: ['276098100123456'],
      ),
      IdentifierProblem.duplicate,
    );
  });

  test('a scanned code gives the chip number in it', () {
    // The Code 128 on a passport sticker.
    expect(
      IdentifierRules.chipFromBarcode('643094100000001'),
      (type: IdentifierType.isoChip, code: '643094100000001'),
    );
    // A word before it, groups, a date after it, a registry's link.
    for (final code in [
      'ISO 643094100000001',
      '643 099-200.041 557',
      '643094100000001 2021-08-14',
      'https://registry.example/pet?chip=643094100000001',
    ]) {
      expect(
        IdentifierRules.chipFromBarcode(code),
        (type: IdentifierType.isoChip, code: '643094100000001'),
        reason: code,
      );
    }
    // Older chips: the whole code, upper case.
    expect(
      IdentifierRules.chipFromBarcode('0a1b2c3d4e'),
      (type: IdentifierType.legacyChip, code: '0A1B2C3D4E'),
    );
    expect(
      IdentifierRules.chipFromBarcode('123*456*789'),
      (type: IdentifierType.legacyChip, code: '123456789'),
    );
  });

  test('other codes give no chip number', () {
    for (final code in [
      '4006381333931', // a product's EAN-13
      '6430941000000011', // 16 digits: no 15 of them are a number of their own
      'AVID 123456789', // 9 digits, but not the whole code
      'WIFI:S:home;T:WPA;P:secret;;',
      '',
    ]) {
      expect(IdentifierRules.chipFromBarcode(code), isNull, reason: code);
    }
  });

  test('ISO numbers are shown in groups of three', () {
    expect(
      IdentifierRules.display(IdentifierType.isoChip, '276098100123456'),
      '276 098 100 123 456',
    );
    expect(IdentifierRules.display(IdentifierType.tattoo, 'AB12'), 'AB12');
  });
}
