import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:collarbell/theme/collarbell_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generated tokens', () {
    test("the designer's palette: bright green primary, yellow accent", () {
      expect(CbTokenColors.light.primary.toARGB32(), 0xFF00B53F);
      expect(CbTokenColors.dark.primary.toARGB32(), 0xFF00B53F);
      // Green words on white: a darker shade of the same green.
      expect(CbTokenColors.light.primaryText.toARGB32(), 0xFF007F2B);
      expect(CbTokenColors.dark.primaryText.toARGB32(), 0xFF00B53F);
      expect(CbTokenColors.light.onPrimary.toARGB32(), 0xFFFFFFFF);
      expect(CbTokenColors.light.paper.toARGB32(), 0xFFFFFFFF);
      expect(CbTokenColors.light.accent.toARGB32(), 0xFFFFDC5F);
      expect(CbTokenColors.light.onAccent.toARGB32(), 0xFF191E28);
      expect(CbTokenColors.light.lineStrong.toARGB32(), 0xFFA5B9DC);
      expect(CbTokenColors.light.avatar.toARGB32(), 0xFFE6EBFA);
      expect(CbTokenColors.light.onAvatar.toARGB32(), 0xFF415064);
    });

    test('aliases are resolved per theme', () {
      for (final colors in [CbTokenColors.light, CbTokenColors.dark]) {
        expect(colors.successSoft, colors.primarySoft);
      }
      // `success` is the bright green of "done" graphics, never words.
      expect(CbTokenColors.light.success.toARGB32(), 0xFF00B53F);
      expect(
        CbTokenColors.light.success,
        isNot(CbTokenColors.light.primaryText),
      );
    });

    test('8-digit hex keeps its alpha (#rrggbbaa -> 0xAARRGGBB)', () {
      final card = CbTokenShadows.light.card;
      expect(card, hasLength(2));
      expect(card.first.color.toARGB32(), 0x0A191E28);
      expect(card.first.offset, const Offset(0, 1));
      expect(card.first.blurRadius, 2);
      expect(card.last.blurRadius, 20);
      expect(CbTokenShadows.dark.card.single.color.toARGB32(), 0x66000000);
      expect(CbTokenShadows.light.focusRing.last.spreadRadius, 4);
    });

    test('numeric scales', () {
      expect(CbSpace.s1, 4);
      expect(CbSpace.s4, 16);
      expect(CbSpace.s12, 48);
      expect(CbRadius.md, 14);
      expect(CbRadius.lg, 20);
      expect(CbRadius.full, 9999);
      expect(CbSize.controlSm, 36);
      expect(CbSize.controlMd, 44);
      expect(CbSize.borderWidth, 1.5);
      expect(CbSize.avatarMd, 40);
    });

    test('type specs: height = lineHeight / fontSize, em -> px', () {
      const xl = CbTypeScale.displayXl;
      expect(xl.family, CbFontFamily.display);
      expect(xl.fontSize, 40);
      expect(xl.height, closeTo(1.1, 1e-9));
      expect(xl.lineHeight, closeTo(44, 1e-9));
      expect(xl.fontWeight, FontWeight.w700);
      expect(xl.letterSpacing, closeTo(-0.8, 1e-9));

      expect(CbTypeScale.body.family, CbFontFamily.sans);
      expect(CbTypeScale.body.fontSize, 16);
      expect(CbTypeScale.body.height, 1.5);
      expect(CbTypeScale.body.letterSpacing, 0);
      expect(CbTypeScale.subtitle.fontWeight, FontWeight.w400);
      expect(CbTypeScale.overline.letterSpacing, closeTo(0.44, 1e-9));
      expect(CbTypeScale.code.family, CbFontFamily.mono);
      expect(CbFontFamily.sans.familyName, 'Helvetica Neue');
      expect(CbFontFamily.display.familyName, 'Helvetica Neue');
      expect(CbTypeScale.all, hasLength(11));
    });

    test('only the weights the fonts have: 400, 500, 700', () {
      for (final spec in CbTypeScale.all) {
        expect(
          [FontWeight.w400, FontWeight.w500, FontWeight.w700],
          contains(spec.fontWeight),
          reason: spec.name,
        );
      }
    });
  });

  group('fonts', () {
    test('Helvetica Neue on iPhone and Mac, Arimo elsewhere', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        expect(fontFamilyFor(CbFontFamily.sans, platform), 'Helvetica Neue');
        expect(fontFamilyFor(CbFontFamily.display, platform), 'Helvetica Neue');
      }
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(fontFamilyFor(CbFontFamily.sans, platform), 'Arimo');
        expect(fontFamilyFor(CbFontFamily.display, platform), 'Arimo');
      }
      expect(
        fontFamilyFor(CbFontFamily.mono, TargetPlatform.iOS),
        'JetBrains Mono',
      );
      expect(
        fontFamilyFor(CbFontFamily.mono, TargetPlatform.android),
        'JetBrains Mono',
      );
    });

    test('the theme picks the font by the platform', () {
      TextStyle body() =>
          CollarbellTheme.light().extension<CbTextStyles>()!.body;

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(body().fontFamily, 'Helvetica Neue');
        expect(body().fontFamilyFallback, ['Arimo']);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(body().fontFamily, 'Arimo');
        expect(body().fontWeight, FontWeight.w400);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('CollarbellTheme', () {
    test('maps the tokens onto the Material colour scheme', () {
      final theme = CollarbellTheme.light(fonts: plainFontResolver);
      final scheme = theme.colorScheme;
      const c = CbTokenColors.light;

      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, c.paper);
      expect(scheme.primary, c.primary);
      expect(scheme.primaryContainer, c.primarySoft);
      expect(scheme.secondary, c.accent);
      expect(scheme.onSecondary, c.onAccent);
      expect(scheme.error, c.danger);
      expect(scheme.errorContainer, c.dangerSoft);
      expect(scheme.onSurfaceVariant, c.inkMuted);
      expect(scheme.outline, c.lineStrong);
      expect(scheme.outlineVariant, c.line);
      expect(scheme.surfaceContainerHighest, c.sunken);
      expect(scheme.inverseSurface, c.inverseSurface);
      expect(theme.extension<CbColors>()!.tokens, same(c));
    });

    test('dark theme uses the dark tokens and the type scale', () {
      final theme = CollarbellTheme.dark(fonts: plainFontResolver);
      final text = theme.extension<CbTextStyles>()!;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, CbTokenColors.dark.primary);
      expect(text.displayLg.fontFamily, 'Helvetica Neue');
      expect(text.body.fontFamily, 'Helvetica Neue');
      expect(text.code.fontFamily, 'JetBrains Mono');
      expect(text.body.fontSize, 16);
      expect(theme.textTheme.bodyMedium!.fontSize, 16);
    });

    test('every button is 44 high; outlines are 1.5 px line-strong', () {
      final theme = CollarbellTheme.light(fonts: plainFontResolver);
      const c = CbTokenColors.light;
      const none = <WidgetState>{};
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
      ]) {
        expect(style.minimumSize!.resolve(none)!.height, CbSize.controlMd);
      }
      expect(
        theme.floatingActionButtonTheme.extendedSizeConstraints!.minHeight,
        CbSize.controlMd,
      );
      final outline = theme.outlinedButtonTheme.style!.side!.resolve(none)!;
      expect(outline.width, CbSize.borderWidth);
      expect(outline.color, c.lineStrong);

      final input = theme.inputDecorationTheme;
      expect(input.enabledBorder!.borderSide.width, CbSize.borderWidth);
      expect(input.enabledBorder!.borderSide.color, c.lineStrong);
      expect(input.focusedBorder!.borderSide.width, 2);
      expect(input.focusedBorder!.borderSide.color, c.primaryText);
      expect(input.errorBorder!.borderSide.color, c.danger);

      BorderSide? chip(Set<WidgetState> states) =>
          WidgetStateProperty.resolveAs(theme.chipTheme.side, states);
      expect(chip(none)!.width, CbSize.borderWidth);
      expect(chip(none)!.color, c.lineStrong);
      expect(chip({WidgetState.selected})!.width, CbSize.borderWidth);
    });

    test('bright green fills, darker green words', () {
      final theme = CollarbellTheme.light(fonts: plainFontResolver);
      const c = CbTokenColors.light;
      const none = <WidgetState>{};
      const selected = {WidgetState.selected};

      // Filled buttons and the FAB: bright fill, white bold words.
      final filled = theme.filledButtonTheme.style!;
      expect(filled.backgroundColor!.resolve(none), c.primary);
      expect(filled.foregroundColor!.resolve(none), c.onPrimary);
      expect(filled.textStyle!.resolve(none)!.fontWeight, FontWeight.w700);
      final fab = theme.floatingActionButtonTheme;
      expect(fab.backgroundColor, c.primary);
      expect(fab.foregroundColor, c.onPrimary);
      expect(fab.extendedTextStyle!.fontWeight, FontWeight.w700);
      // The other buttons keep the `label` weight.
      for (final style in [
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
      ]) {
        expect(style.textStyle!.resolve(none)!.fontWeight, FontWeight.w500);
      }

      // Green words and thin lines: `primary-text`.
      expect(
        theme.textButtonTheme.style!.foregroundColor!.resolve(none),
        c.primaryText,
      );
      expect(theme.tabBarTheme.labelColor, c.primaryText);
      expect(theme.tabBarTheme.indicatorColor, c.primaryText);
      final nav = theme.navigationBarTheme;
      expect(nav.indicatorColor, c.primarySoft);
      expect(nav.iconTheme!.resolve(selected)!.color, c.primaryText);
      expect(nav.labelTextStyle!.resolve(selected)!.color, c.primaryText);
      expect(nav.iconTheme!.resolve(none)!.color, c.inkMuted);
      expect(theme.chipTheme.secondaryLabelStyle!.color, c.primaryText);
      expect(theme.chipTheme.checkmarkColor, c.primaryText);
      expect(
        theme.segmentedButtonTheme.style!.foregroundColor!.resolve(selected),
        c.primaryText,
      );
      expect(theme.listTileTheme.selectedColor, c.primaryText);
      expect(theme.textSelectionTheme.cursorColor, c.primaryText);

      // Fills stay bright.
      expect(theme.switchTheme.trackColor!.resolve(selected), c.primary);
      expect(theme.radioTheme.fillColor!.resolve(selected), c.primary);
      expect(theme.progressIndicatorTheme.color, c.primary);
    });

    test(
      'icons: Material Symbols, weight 400 at optical size 48, everywhere',
      () {
        final theme = CollarbellTheme.light(fonts: plainFontResolver);
        expect(theme.iconTheme.weight, CbIcons.weight);
        expect(CbIcons.weight, 400);
        expect(theme.iconTheme.fill, 0);
        expect(theme.iconTheme.opticalSize, 48);
        expect(
          theme.navigationBarTheme.iconTheme!.resolve({
            WidgetState.selected,
          })!.weight,
          CbIcons.weight,
        );
        expect(theme.appBarTheme.iconTheme!.weight, CbIcons.weight);
        expect(theme.chipTheme.iconTheme!.weight, CbIcons.weight);
      },
    );
  });

  testWidgets('as drawn: buttons, segments and fields 44, chips 36', (
    tester,
  ) async {
    // Without the touch-area padding, so the sizes are what one sees.
    final theme = CollarbellTheme.light(
      fonts: plainFontResolver,
    ).copyWith(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Save')),
              OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
              TextButton(onPressed: () {}, child: const Text('Change')),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Cat')),
                  ButtonSegment(value: 2, label: Text('Dog')),
                ],
                selected: const {1},
              ),
              FloatingActionButton.extended(
                onPressed: () {},
                icon: const Icon(Symbols.add_rounded),
                label: const Text('Add'),
              ),
              ChoiceChip(label: const Text('Cat'), selected: true),
              FilterChip(label: const Text('Dog'), onSelected: (_) {}),
              const TextField(key: ValueKey('plain')),
              const TextField(
                key: ValueKey('withIcon'),
                decoration: InputDecoration(
                  suffixIcon: Icon(Symbols.event_rounded),
                ),
              ),
              DropdownButtonFormField<int>(
                key: const ValueKey('dropdown'),
                icon: cbDropdownIcon,
                initialValue: 1,
                items: const [DropdownMenuItem(value: 1, child: Text('One'))],
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    double height(Finder finder) => tester.getSize(finder.first).height;
    expect(height(find.byType(FilledButton)), CbSize.controlMd);
    expect(height(find.byType(OutlinedButton)), CbSize.controlMd);
    expect(height(find.widgetWithText(TextButton, 'Change')), CbSize.controlMd);
    expect(height(find.byType(SegmentedButton<int>)), CbSize.controlMd);
    expect(height(find.byType(FloatingActionButton)), CbSize.controlMd);
    expect(height(find.byType(ChoiceChip)), CbSize.controlSm);
    expect(height(find.byType(FilterChip)), CbSize.controlSm);

    // Fields: 44 high, a trailing icon (or a dropdown's arrow) 16 in from
    // the right edge, as the words are from the left.
    for (final key in ['plain', 'withIcon', 'dropdown']) {
      expect(height(find.byKey(ValueKey(key))), CbSize.controlMd, reason: key);
    }
    // From the field's right edge to the 24-px icon around the glyph's
    // centre (the icon's box may be stretched wider, the glyph narrower).
    double inset(String key, IconData icon) {
      final glyph = find.descendant(
        of: find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byIcon(icon),
        ),
        matching: find.byType(RichText),
      );
      return tester.getTopRight(find.byKey(ValueKey(key))).dx -
          (tester.getCenter(glyph).dx + 12);
    }

    expect(inset('withIcon', Symbols.event_rounded), CbSpace.s4);
    expect(inset('dropdown', Symbols.expand_more_rounded), CbSpace.s4);
  });
}
