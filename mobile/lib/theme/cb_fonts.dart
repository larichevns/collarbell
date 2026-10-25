import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'tokens.g.dart';

/// Turns a token font family into a concrete [TextStyle].
///
/// The theme takes a resolver so tests can pick the font names they need
/// (see [plainFontResolver]).
typedef CbFontResolver =
    TextStyle Function(CbFontFamily family, TextStyle style);

/// The bundled interface font for phones without Helvetica Neue: Arimo, the
/// free twin of Arial (same shapes and widths). pubspec.yaml declares it
/// with its three weights: 400, 500 and 700.
const bundledSansFamily = 'Arimo';

/// Production fonts: the interface in Helvetica Neue on iPhone and Mac (a
/// system font there, nothing to bundle), in the bundled Arimo elsewhere
/// (Android); chip numbers and codes in JetBrains Mono.
///
/// The platform comes from [defaultTargetPlatform], so a test can pick one
/// with `debugDefaultTargetPlatformOverride`. The bundled fonts ship in
/// `assets/google_fonts/`, so text never flashes in a fallback font.
TextStyle platformFontResolver(CbFontFamily family, TextStyle style) {
  final name = fontFamilyFor(family, defaultTargetPlatform);
  return style.copyWith(
    fontFamily: name,
    // Should a system lack Helvetica Neue, Arimo looks the same.
    fontFamilyFallback: name == bundledSansFamily
        ? null
        : const [bundledSansFamily],
  );
}

/// The font family [family] uses on [platform].
String fontFamilyFor(CbFontFamily family, TargetPlatform platform) {
  if (family == CbFontFamily.mono) return family.familyName;
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => family.familyName,
    _ => bundledSansFamily,
  };
}

/// Sets the token family name only ('Helvetica Neue', 'JetBrains Mono'),
/// whatever the platform. For widget tests.
TextStyle plainFontResolver(CbFontFamily family, TextStyle style) {
  return style.copyWith(fontFamily: family.familyName);
}
