import 'package:flutter/foundation.dart';

/// The server's rules for the passport number and country, checked in the
/// app (the passport form, the scan) so mistakes show before saving.
abstract final class PassportRules {
  /// Letters, digits, hyphens and slashes, up to 30, after [normalizeNumber].
  static final number = RegExp(r'^[A-Z0-9/-]{1,30}$');

  /// A two-letter country code (ISO 3166-1), e.g. `DE`.
  static final country = RegExp(r'^[A-Za-z]{2}$');

  /// Spaces don't count and letters are compared in upper case, as on the
  /// server: `de 123` is saved as `DE123`.
  static String normalizeNumber(String value) =>
      value.replaceAll(RegExp(r'\s'), '').toUpperCase();
}

/// The printed form of the passport.
enum PassportModel {
  /// EU pet passport, Regulation 577/2013 (issued from 29.12.2014).
  eu2014,

  /// EU pet passport, Implementing Regulation 2026/705 (issued from
  /// 22.04.2026).
  eu2026,

  /// Any other passport, e.g. an international veterinary passport.
  other,
}

/// A person in the passport: the issuing vet or an owner.
@immutable
class PassportContact {
  const PassportContact({this.name, this.address, this.phone, this.email});

  final String? name;
  final String? address;
  final String? phone;
  final String? email;

  bool get isEmpty =>
      name == null && address == null && phone == null && email == null;

  @override
  bool operator ==(Object other) =>
      other is PassportContact &&
      other.name == name &&
      other.address == address &&
      other.phone == phone &&
      other.email == email;

  @override
  int get hashCode => Object.hash(name, address, phone, email);

  @override
  String toString() => 'PassportContact($name)';
}

/// The header of the pet's digital passport copy: what the paper passport
/// says that isn't stored elsewhere. The copy is for information only; the
/// paper passport stays the official document.
@immutable
class Passport {
  const Passport({
    this.model,
    this.number,
    this.issuingCountry,
    this.issuedOn,
    this.issuer,
    this.owners = const [],
    this.notes,
    this.updatedAt,
  });

  final PassportModel? model;

  /// Upper case without spaces, e.g. `DE-1234567`.
  final String? number;

  /// Two-letter country code (ISO 3166-1), e.g. `DE`.
  final String? issuingCountry;
  final DateTime? issuedOn;

  /// The vet who issued the passport.
  final PassportContact? issuer;

  /// Up to two owners, as in section I of the passport.
  final List<PassportContact> owners;
  final String? notes;

  /// Null until the header is saved for the first time.
  final DateTime? updatedAt;

  bool get isSaved => updatedAt != null;

  static const maxOwners = 2;

  @override
  bool operator ==(Object other) =>
      other is Passport &&
      other.model == model &&
      other.number == number &&
      other.issuingCountry == issuingCountry &&
      other.issuedOn == issuedOn &&
      other.issuer == issuer &&
      listEquals(other.owners, owners) &&
      other.notes == notes &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    model,
    number,
    issuingCountry,
    issuedOn,
    issuer,
    Object.hashAll(owners),
    notes,
    updatedAt,
  );

  @override
  String toString() => 'Passport($number)';
}
