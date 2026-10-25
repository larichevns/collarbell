import 'package:flutter/material.dart';

import 'cb_fonts.dart';
import 'tokens.g.dart';

/// All Collarbell colour tokens (aliases such as `success-soft` included) as
/// a [ThemeExtension]. Read them with `context.cb`.
@immutable
class CbColors extends ThemeExtension<CbColors> {
  const CbColors(this.tokens);

  final CbTokenColors tokens;

  @override
  CbColors copyWith({CbTokenColors? tokens}) => CbColors(tokens ?? this.tokens);

  @override
  CbColors lerp(covariant CbColors? other, double t) {
    if (other == null) return this;
    return CbColors(CbTokenColors.lerp(tokens, other.tokens, t));
  }
}

/// Shadow tokens as a [ThemeExtension]. Read them with `context.cbShadows`.
@immutable
class CbShadows extends ThemeExtension<CbShadows> {
  const CbShadows(this.tokens);

  final CbTokenShadows tokens;

  @override
  CbShadows copyWith({CbTokenShadows? tokens}) =>
      CbShadows(tokens ?? this.tokens);

  @override
  CbShadows lerp(covariant CbShadows? other, double t) {
    if (other == null) return this;
    return CbShadows(CbTokenShadows.lerp(tokens, other.tokens, t));
  }
}

/// The Collarbell type scale with fonts applied. Read it with
/// `context.cbText`, e.g. `context.cbText.displayXl`. Every style is
/// Helvetica Neue on iPhone and Arimo on Android ([platformFontResolver]),
/// except [code] in JetBrains Mono.
///
/// Styles carry no colour, so text takes the ambient colour (ink on screens,
/// the button colour inside buttons). The fonts have three weights only:
/// 400, 500 and 700; never ask for 600. Hierarchy comes from size and
/// colour: headings bold in `ink`, names in rows regular, second lines in
/// `ink-muted`.
@immutable
class CbTextStyles extends ThemeExtension<CbTextStyles> {
  const CbTextStyles({
    required this.displayXl,
    required this.displayLg,
    required this.numeral,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.bodySm,
    required this.label,
    required this.caption,
    required this.overline,
    required this.code,
  });

  /// Builds every style from [CbTypeScale] with the given font resolver.
  factory CbTextStyles.resolve(CbFontResolver fonts) {
    TextStyle style(CbTypeSpec spec, {bool tabularFigures = false}) {
      return fonts(
        spec.family,
        TextStyle(
          fontSize: spec.fontSize,
          height: spec.height,
          fontWeight: spec.fontWeight,
          letterSpacing: spec.letterSpacing,
          leadingDistribution: TextLeadingDistribution.even,
          fontFeatures: tabularFigures
              ? const [FontFeature.tabularFigures()]
              : null,
        ),
      );
    }

    return CbTextStyles(
      displayXl: style(CbTypeScale.displayXl, tabularFigures: true),
      displayLg: style(CbTypeScale.displayLg),
      numeral: style(CbTypeScale.numeral, tabularFigures: true),
      title: style(CbTypeScale.title),
      subtitle: style(CbTypeScale.subtitle),
      body: style(CbTypeScale.body),
      bodySm: style(CbTypeScale.bodySm),
      label: style(CbTypeScale.label),
      caption: style(CbTypeScale.caption),
      overline: style(CbTypeScale.overline),
      code: style(CbTypeScale.code, tabularFigures: true),
    );
  }

  /// 40/44 bold: one big number per screen (next feeding, days left).
  final TextStyle displayXl;

  /// 28/34 bold: the screen title, one per screen.
  final TextStyle displayLg;

  /// 20/24 medium with tabular figures: numbers in rows.
  final TextStyle numeral;

  /// 20/26 bold: card and section titles.
  final TextStyle title;

  /// 17/24 regular: the name in a row (task, product, pet).
  final TextStyle subtitle;

  /// 16/24: body text, never smaller on a phone.
  final TextStyle body;

  /// 14/20: second line of a row.
  final TextStyle bodySm;

  /// 15/20 medium: buttons, chips, field labels.
  final TextStyle label;

  /// 12/16: metadata, badges, hints.
  final TextStyle caption;

  /// 11/14 medium, wide tracking. Upper-case strings only.
  final TextStyle overline;

  /// JetBrains Mono 14/20: chip, batch and passport numbers.
  final TextStyle code;

  @override
  CbTextStyles copyWith({
    TextStyle? displayXl,
    TextStyle? displayLg,
    TextStyle? numeral,
    TextStyle? title,
    TextStyle? subtitle,
    TextStyle? body,
    TextStyle? bodySm,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? overline,
    TextStyle? code,
  }) {
    return CbTextStyles(
      displayXl: displayXl ?? this.displayXl,
      displayLg: displayLg ?? this.displayLg,
      numeral: numeral ?? this.numeral,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      body: body ?? this.body,
      bodySm: bodySm ?? this.bodySm,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      overline: overline ?? this.overline,
      code: code ?? this.code,
    );
  }

  @override
  CbTextStyles lerp(covariant CbTextStyles? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return CbTextStyles(
      displayXl: mix(displayXl, other.displayXl),
      displayLg: mix(displayLg, other.displayLg),
      numeral: mix(numeral, other.numeral),
      title: mix(title, other.title),
      subtitle: mix(subtitle, other.subtitle),
      body: mix(body, other.body),
      bodySm: mix(bodySm, other.bodySm),
      label: mix(label, other.label),
      caption: mix(caption, other.caption),
      overline: mix(overline, other.overline),
      code: mix(code, other.code),
    );
  }
}

/// Shortcuts to the Collarbell theme extensions.
extension CbThemeContext on BuildContext {
  /// Colour tokens of the current theme, e.g. `context.cb.inkMuted`.
  CbTokenColors get cb => _extension<CbColors>(this).tokens;

  /// Shadow tokens of the current theme, e.g. `context.cbShadows.card`.
  CbTokenShadows get cbShadows => _extension<CbShadows>(this).tokens;

  /// The type scale, e.g. `context.cbText.displayXl`.
  CbTextStyles get cbText => _extension<CbTextStyles>(this);
}

T _extension<T>(BuildContext context) {
  final extension = Theme.of(context).extension<T>();
  if (extension == null) {
    throw FlutterError(
      '$T is missing from the theme. Build ThemeData with '
      'CollarbellTheme.light() or CollarbellTheme.dark().',
    );
  }
  return extension;
}
