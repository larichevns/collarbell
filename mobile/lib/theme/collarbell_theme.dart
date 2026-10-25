import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'cb_fonts.dart';
import 'cb_theme_extensions.dart';
import 'tokens.g.dart';

export 'package:material_symbols_icons/symbols.dart';

export 'cb_fonts.dart';
export 'cb_theme_extensions.dart';
export 'tokens.g.dart';

/// How the app draws its icons: Material Symbols Rounded
/// (`Symbols.<name>_rounded`, the family the web app draws too), outlined,
/// weight 400 drawn for the 48-px optical size: at 20–24 px a little
/// thinner than Material's usual icons, as the designer asked, and the same
/// strokes as the web app's icons (its SVGs are drawn at that size). A
/// filled glyph is the same icon with `fill: 1` (e.g. the selected tab in
/// the navigation bar). The theme sets these once ([ThemeData.iconTheme]);
/// the components that build their own icon theme get them too. This file
/// exports `Symbols`, so a screen that imports the theme has the icons.
abstract final class CbIcons {
  static const double weight = 400;

  /// The size the glyphs' strokes are designed for. 48 on a 24-px icon
  /// gives thinner lines than 24 would; weight 300 was far too thin.
  static const double opticalSize = 48;
}

/// Material themes built from the Collarbell design tokens.
///
/// Light is the default theme. Design rules the component themes follow:
/// screens are white with a blue-grey interface. The green comes in two
/// shades: `primary` (the bright #00B53F) is only a FILL — the main button
/// and the FAB (their words white and bold), the switch, the radio,
/// progress; `primary-text` (the darker #007F2B) is every green WORD and
/// thin green line on white or mint — text buttons, the selected tab, chip
/// and segment, the focused field, the cursor. `accent` (yellow) is only a
/// fill, e.g. the "soon" status tag (`CbStatusTag`), never text on white;
/// `danger` (red) is only for overdue items, errors and deleting. Every
/// button and input is `control-md` (44) high, chips are `control-sm` (36);
/// outlines of buttons, inputs and chips are `border-width` (1.5) in
/// `line-strong`. Body text is at least 16 px.
abstract final class CollarbellTheme {
  static ThemeData light({CbFontResolver fonts = platformFontResolver}) {
    return _build(
      Brightness.light,
      CbTokenColors.light,
      CbTokenShadows.light,
      fonts,
    );
  }

  static ThemeData dark({CbFontResolver fonts = platformFontResolver}) {
    return _build(
      Brightness.dark,
      CbTokenColors.dark,
      CbTokenShadows.dark,
      fonts,
    );
  }

  /// Flutter's default on Android, but without the predictive back preview.
  ///
  /// That preview hands a back swipe to the top page of every navigator,
  /// and a tab keeps its own navigator under the app's one: with the
  /// barcode scanner, a dialog or a picker open over a tab's screen, the
  /// swipe also popped the screen hidden under it, and closing what was
  /// on top then left no page at all (a black screen). Without the preview
  /// the swipe is a plain Back, which go_router gives to the topmost route
  /// only. Pages still come and go with the same fade-forwards transition.
  static const pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(),
    },
  );

  /// Status and navigation bar colours that match the theme. The app has no
  /// AppBars, so the root widget applies this with an [AnnotatedRegion].
  static SystemUiOverlayStyle systemOverlayStyle(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final iconBrightness = dark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: theme.brightness,
      systemNavigationBarColor: theme.colorScheme.surface,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarDividerColor: const Color(0x00000000),
    );
  }

  static ThemeData _build(
    Brightness brightness,
    CbTokenColors c,
    CbTokenShadows shadows,
    CbFontResolver fonts,
  ) {
    final text = CbTextStyles.resolve(fonts);
    const transparent = Color(0x00000000);
    // What dims the screen under a dialog or a sheet: the palette's darkest
    // blue at half strength. Material's black turns the white screen grey.
    const scrim = Color(0x80191E28);
    const pill = StadiumBorder();
    final buttonTextStyle = WidgetStatePropertyAll<TextStyle>(text.label);
    // White on the bright green is only 2.7:1, so the words of a filled
    // button and of the FAB are bold (owner's decision); every other button
    // keeps the `label` weight, 500.
    final filledLabel = text.label.copyWith(fontWeight: FontWeight.w700);
    // Every icon: outlined, weight 400 at optical size 48 (see CbIcons).
    final icons = IconThemeData(
      color: c.ink,
      fill: 0,
      weight: CbIcons.weight,
      grade: 0,
      opticalSize: CbIcons.opticalSize,
    );
    const buttonMinimumSize = WidgetStatePropertyAll<Size>(
      Size(64, CbSize.controlMd),
    );
    const buttonPadding = WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: CbSpace.s5),
    );
    // Outlines of buttons, inputs, chips and segments: 1.5 px, `line-strong`.
    BorderSide outline(Color color) =>
        BorderSide(color: color, width: CbSize.borderWidth);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.ink,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.ink,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.ink,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceContainerHighest: c.sunken,
      outline: c.lineStrong,
      outlineVariant: c.line,
      inverseSurface: c.inverseSurface,
      onInverseSurface: c.onInverse,
      inversePrimary: c.inversePrimary,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF191E28),
      // No Material 3 tonal tint: raised surfaces stay white.
      surfaceTint: transparent,
    );

    final textTheme = TextTheme(
      displayLarge: text.displayXl,
      displayMedium: text.displayLg,
      displaySmall: text.numeral,
      headlineLarge: text.title,
      headlineMedium: text.title,
      headlineSmall: text.title,
      titleLarge: text.title,
      titleMedium: text.subtitle,
      titleSmall: text.label,
      bodyLarge: text.body,
      bodyMedium: text.body,
      bodySmall: text.bodySm,
      labelLarge: text.label,
      labelMedium: text.caption,
      labelSmall: text.overline,
    ).apply(bodyColor: c.ink, displayColor: c.ink);

    OutlineInputBorder inputBorder(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(CbRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      pageTransitionsTheme: pageTransitions,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      dividerColor: c.line,
      textTheme: textTheme,
      primaryTextTheme: textTheme.apply(
        bodyColor: c.onPrimary,
        displayColor: c.onPrimary,
      ),
      iconTheme: icons,
      // Back and close arrows of the AppBars in the same icons as the rest.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) =>
            Icon(switch (Theme.of(context).platform) {
              TargetPlatform.iOS ||
              TargetPlatform.macOS => Symbols.arrow_back_ios_new_rounded,
              _ => Symbols.arrow_back_rounded,
            }),
        closeButtonIconBuilder: (context) => const Icon(Symbols.close_rounded),
      ),
      extensions: [CbColors(c), CbShadows(shadows), text],
      // Also FilledButton.tonal: it takes this theme too, so it is the same
      // bright pill.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinimumSize,
          padding: buttonPadding,
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(filledLabel),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.sunken;
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return c.primaryStrong;
            }
            return c.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.inkDisabled
                : c.onPrimary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinimumSize,
          padding: buttonPadding,
          shape: const WidgetStatePropertyAll(pill),
          textStyle: buttonTextStyle,
          backgroundColor: const WidgetStatePropertyAll(transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? c.inkDisabled : c.ink,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => outline(
              states.contains(WidgetState.disabled) ? c.line : c.lineStrong,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(CbSize.controlMd, CbSize.controlMd),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: CbSpace.s3),
          ),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: buttonTextStyle,
          // Green words on white: `primary-text`.
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.inkDisabled
                : c.primaryText,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(CbSize.controlMd, CbSize.controlMd),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.inkDisabled
                : c.inkMuted,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.surface,
        // Labels are rendered above the field (see CbTextField), never inside.
        floatingLabelBehavior: FloatingLabelBehavior.never,
        // 44 high, as every button: the 24-px line of `body` and 10 above
        // and below; the words 16 in from the left edge.
        contentPadding: EdgeInsets.symmetric(
          horizontal: CbSpace.s4,
          vertical:
              (CbSize.controlMd - text.body.fontSize! * text.body.height!) / 2,
        ),
        constraints: const BoxConstraints(minHeight: CbSize.controlMd),
        // Without it Material keeps fields at least 48 high.
        isDense: true,
        // A trailing icon (calendar, clock, eye) 16 in from the right edge,
        // as the words are from the left: a 24-px icon centred in 56.
        suffixIconConstraints: const BoxConstraints(
          minWidth: 24 + 2 * CbSpace.s4,
          minHeight: CbSize.controlMd,
        ),
        hintStyle: text.body.copyWith(color: c.inkMuted),
        helperStyle: text.caption.copyWith(color: c.inkMuted),
        errorStyle: text.caption.copyWith(color: c.danger),
        errorMaxLines: 3,
        prefixIconColor: c.inkMuted,
        suffixIconColor: c.inkMuted,
        border: inputBorder(c.lineStrong, CbSize.borderWidth),
        enabledBorder: inputBorder(c.lineStrong, CbSize.borderWidth),
        disabledBorder: inputBorder(c.line, CbSize.borderWidth),
        // A thin green line on white: `primary-text`.
        focusedBorder: inputBorder(c.primaryText, 2),
        errorBorder: inputBorder(c.danger, CbSize.borderWidth),
        focusedErrorBorder: inputBorder(c.danger, 2),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primaryText,
        // A fill behind the words: the bright green, faint.
        selectionColor: c.primary.withValues(alpha: 0.24),
        selectionHandleColor: c.primaryText,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: transparent,
        shadowColor: transparent,
        // The soft `shadow-card` is drawn by CbCard: Material elevation
        // cannot express the token's two-layer shadow.
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CbRadius.lg),
          side: BorderSide(color: c.line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: transparent,
        shadowColor: transparent,
        elevation: 0,
        // Selected: a mint pill, the icon (filled) and the word in
        // `primary-text`.
        indicatorColor: c.primarySoft,
        indicatorShape: pill,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => icons.copyWith(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? c.primaryText
                : c.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? c.primaryText
                : c.inkMuted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.inverseSurface,
        contentTextStyle: text.body.copyWith(color: c.onInverse),
        actionTextColor: c.inversePrimary,
        closeIconColor: c.onInverse,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CbRadius.lg),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        // `control-sm` (36) high: the 20 px label line, the outline on both
        // sides and this padding make it up.
        padding: EdgeInsets.symmetric(
          horizontal: CbSpace.s2,
          vertical:
              (CbSize.controlSm -
                  text.label.fontSize! * text.label.height! -
                  2 * CbSize.borderWidth) /
              2,
        ),
        // Words `ink`; on a selected chip (mint) `primary-text`, as its tick
        // and its icon. Choice chips take `secondaryLabelStyle` when
        // selected, filter chips resolve the colour by state.
        labelStyle: text.label.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? c.primaryText : c.ink,
          ),
        ),
        secondaryLabelStyle: text.label.copyWith(color: c.primaryText),
        checkmarkColor: c.primaryText,
        iconTheme: icons.copyWith(color: c.primaryText, size: 18),
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.primarySoft;
          return c.surface;
        }),
        // Selected: the same 1.5 px outline in the fill colour, so the chip
        // keeps its size.
        side: WidgetStateBorderSide.resolveWith(
          (states) => outline(
            states.contains(WidgetState.selected)
                ? c.primarySoft
                : c.lineStrong,
          ),
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: c.paper,
        foregroundColor: c.ink,
        surfaceTintColor: transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.title.copyWith(color: c.ink),
        // Without these, the back arrow takes the muted icon-button colour
        // while the actions are ink. The AppBar only passes its icon theme
        // on to the back arrow when it differs from Material's default
        // (onSurface, 24), which `ink` is: `opacity: 1` makes it differ.
        iconTheme: icons.copyWith(size: 24, opacity: 1),
        actionsIconTheme: icons.copyWith(size: 24),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.inkMuted,
        // A selected row (the current household): its words and icon in
        // `primary-text`, not Material's bright `primary`.
        selectedColor: c.primaryText,
        titleTextStyle: text.subtitle.copyWith(color: c.ink),
        subtitleTextStyle: text.bodySm.copyWith(color: c.inkMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: CbSpace.s4),
        minVerticalPadding: CbSpace.s3,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.inkDisabled;
          if (states.contains(WidgetState.selected)) return c.primary;
          return c.lineStrong;
        }),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.sunken,
        circularTrackColor: transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: transparent,
        barrierColor: scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CbRadius.lg),
        ),
        titleTextStyle: text.title.copyWith(color: c.ink),
        contentTextStyle: text.body.copyWith(color: c.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: transparent,
        modalBarrierColor: scrim,
        showDragHandle: true,
        dragHandleColor: c.lineStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(CbRadius.lg),
          ),
        ),
      ),
      // The FAB is the screen's main action, so it is a filled primary pill
      // with white bold words, as a filled button.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        hoverColor: c.primaryStrong,
        splashColor: c.primaryStrong,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 3,
        shape: pill,
        // As high as every other button.
        extendedSizeConstraints: const BoxConstraints.tightFor(
          height: CbSize.controlMd,
        ),
        extendedTextStyle: filledLabel,
      ),
      // The selected tab's word and the line under it: `primary-text`.
      tabBarTheme: TabBarThemeData(
        labelColor: c.primaryText,
        unselectedLabelColor: c.inkMuted,
        labelStyle: text.label,
        unselectedLabelStyle: text.label,
        indicatorColor: c.primaryText,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: c.line,
      ),
      // Selected segments use `primary-soft`, like selected chips; Material's
      // default would take the yellow secondary colour.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // Segments ignore `minimumSize` and are 40 high; one step of
          // density (4 px) makes them 44, as high as every button. 44 is
          // enough to tap: no extra touch area above and below, so the
          // label sits as close above it as above a field.
          visualDensity: const VisualDensity(vertical: 1),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: buttonTextStyle,
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? c.primarySoft
                : c.surface,
          ),
          // Selected: words and tick in `primary-text` on the mint.
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.inkDisabled;
            return states.contains(WidgetState.selected)
                ? c.primaryText
                : c.ink;
          }),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? c.primaryText
                : c.inkMuted,
          ),
          side: WidgetStatePropertyAll(outline(c.lineStrong)),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineWidth: const WidgetStatePropertyAll(CbSize.borderWidth),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.onPrimary
              : c.lineStrong,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.primary : c.sunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.primary : c.lineStrong,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: transparent,
        textStyle: text.body.copyWith(color: c.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CbRadius.md),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: transparent,
        headerForegroundColor: c.ink,
        // The chosen day is a `primary` disc with `on-primary` digits;
        // today, when not chosen, is ringed and written in `primary-text`.
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.onPrimary;
          if (states.contains(WidgetState.disabled)) return c.inkDisabled;
          return c.primaryText;
        }),
        todayBorder: BorderSide(color: c.primaryText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CbRadius.lg),
        ),
      ),
    );
  }
}

/// The style of a round `IconButton.outlined`, e.g. the − and + of a
/// counter, or a section's "+" where there is no room for words: the same
/// 1.5 px `line-strong` outline as every other outlined control (`line`
/// when off), and its icon `ink`, as an outlined button's words. The
/// icon-button theme can't carry it: a plain icon button would get the
/// outline too.
ButtonStyle cbOutlinedIconButtonStyle(BuildContext context) {
  final c = context.cb;
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? c.inkDisabled : c.ink,
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled) ? c.line : c.lineStrong,
        width: CbSize.borderWidth,
      ),
    ),
  );
}

/// A text button in line with the text around it: under left-aligned text
/// (its words start at the same left edge). No side padding, so nothing sits
/// indented; still 44 high. Only for what stays text (a link in a line, an
/// inline "Change"): calls to action are outlined or filled buttons.
const cbInlineTextButtonStyle = ButtonStyle(
  padding: WidgetStatePropertyAll(EdgeInsets.zero),
  minimumSize: WidgetStatePropertyAll(Size(0, CbSize.controlMd)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// An outlined button that fits beside a section's title ("All visits",
/// "Add"): as high as every button (44), with an icon a little smaller and
/// less room at the sides than a full-width one. `CbSection` gives it to an
/// outlined action; a header with no room even for that uses an outlined
/// icon button with a tooltip ([cbOutlinedIconButtonStyle]).
const cbCompactOutlinedButtonStyle = ButtonStyle(
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: CbSpace.s3)),
  minimumSize: WidgetStatePropertyAll(Size(0, CbSize.controlMd)),
  iconSize: WidgetStatePropertyAll(20),
);

/// A `RadioListTile` among `ListTile`s with icons: its circle (20 in a
/// 40-wide radio) centred where their 24-px icons are, and its words at the
/// same left edge as theirs (16 + 24 + 16 = 8 + 40 + 8).
abstract final class CbRadioTile {
  static const contentPadding = EdgeInsetsDirectional.only(
    start: CbSpace.s2,
    end: CbSpace.s4,
  );
  static const titleGap = CbSpace.s2;
}
