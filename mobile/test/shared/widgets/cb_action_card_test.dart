// CbActionCard: a call to action as a card. The whole card is one button
// (also its words), screen readers hear one button with the title and the
// hint, and a grid of compact cards fits a small phone with large text.
import 'package:collarbell/l10n/app_localizations.dart';
import 'package:collarbell/shared/widgets/cb_action_card.dart';
import 'package:collarbell/theme/collarbell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  ThemeData? theme,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? CollarbellTheme.light(fonts: plainFontResolver),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the whole card is one button: the hint is as good a target as '
      'the icon', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      CbActionCard(
        icon: Symbols.restaurant_rounded,
        title: 'Add feeding',
        hint: "We'll remind you when to feed",
        onTap: () => taps++,
      ),
    );

    expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
    await tester.tap(find.text("We'll remind you when to feed"));
    await tester.tap(find.byIcon(Symbols.restaurant_rounded));
    await tester.tap(find.byIcon(Symbols.chevron_right_rounded));
    expect(taps, 3);
    expect(
      tester.getSize(find.byType(CbActionCard)).height,
      greaterThanOrEqualTo(CbActionCard.minHeight),
    );
  });

  testWidgets('screen readers hear one button with the title and the hint', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      CbActionCard(
        icon: Symbols.restaurant_rounded,
        title: 'Add feeding',
        hint: "We'll remind you when to feed",
        onTap: () {},
      ),
    );

    expect(
      // The node the title's words merge into.
      tester.getSemantics(find.text('Add feeding')),
      matchesSemantics(
        label: "Add feeding\nWe'll remind you when to feed",
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the compact card has its icon on top and no chevron', (
    tester,
  ) async {
    await _pump(
      tester,
      CbActionCard.compact(
        icon: Symbols.monitor_weight_rounded,
        title: 'Weigh',
        hint: 'Keep an eye on weight',
        onTap: () {},
      ),
    );

    expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);
    expect(
      tester.getTopLeft(find.byIcon(Symbols.monitor_weight_rounded)).dy,
      lessThan(tester.getTopLeft(find.text('Weigh')).dy),
    );
  });

  testWidgets('the primary card: mint, its circle the bright green', (
    tester,
  ) async {
    await _pump(
      tester,
      CbActionCard(
        primary: true,
        icon: Symbols.pets_rounded,
        title: 'Add a pet',
        onTap: () {},
      ),
    );

    final colors = CbTokenColors.light;
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(CbActionCard),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, colors.primarySoft);
    expect(
      tester.widget<Icon>(find.byIcon(Symbols.pets_rounded)).color,
      colors.onPrimary,
    );
  });

  final gridCards = [
    for (final (title, hint) in [
      ('Прививка или обработка', 'Записать, что сделали'),
      ('Взвесить', 'Следить за весом'),
      ('Сканировать покупку', 'Корм, лекарства'),
    ])
      CbActionCard.compact(
        key: ValueKey(title),
        icon: Symbols.vaccines_rounded,
        title: title,
        hint: hint,
        onTap: () {},
      ),
  ];

  for (final dark in [false, true]) {
    testWidgets('two compact cards a row; a row is as tall as its tallest '
        'card (${dark ? 'dark' : 'light'})', (tester) async {
      await _pump(
        tester,
        CbActionGrid(cards: gridCards),
        theme: dark
            ? CollarbellTheme.dark(fonts: plainFontResolver)
            : CollarbellTheme.light(fonts: plainFontResolver),
      );

      final first = tester.getSize(
        find.byKey(const ValueKey('Прививка или обработка')),
      );
      final second = tester.getSize(find.byKey(const ValueKey('Взвесить')));
      expect(first.height, second.height);
      // The odd last card keeps half the width.
      expect(
        tester.getSize(find.byKey(const ValueKey('Сканировать покупку'))).width,
        first.width,
      );
      expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);
    });
  }

  testWidgets('no room for two (320 dp, large text): one card a row, in the '
      'full layout, nothing cut', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      CbActionGrid(cards: gridCards),
      size: const Size(320, 1200),
    );

    // An overflow would have failed the test by now.
    expect(find.byIcon(Symbols.chevron_right_rounded), findsNWidgets(3));
    expect(
      tester.getSize(find.byKey(const ValueKey('Взвесить'))).width,
      320 - 2 * 16,
    );
  });
}
