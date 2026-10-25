// Loading shows a skeleton of what comes (rows, form fields), not a
// spinner; it is cut off in small spaces and keeps still when the phone asks for
// less motion. A spinner is left for waits that aren't content.
import 'package:collarbell/l10n/app_localizations.dart';
import 'package:collarbell/shared/widgets/state_views.dart';
import 'package:collarbell/theme/collarbell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpLoading(
  WidgetTester tester,
  Widget child, {
  double height = 600,
  bool lessMotion = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: CollarbellTheme.light(fonts: plainFontResolver),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: lessMotion),
      child: Scaffold(
        body: Column(
          children: [SizedBox(height: height, child: child)],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a list loads as a skeleton, read out as "Loading"', (
    tester,
  ) async {
    await pumpLoading(tester, const CbLoadingState());

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('a waiting camera or AI keeps a spinner', (tester) async {
    await pumpLoading(tester, const CbLoadingState.spinner());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a small space cuts the skeleton off, nothing overflows', (
    tester,
  ) async {
    await pumpLoading(tester, const CbLoadingState.form(), height: 150);
    await pumpLoading(tester, const CbLoadingState(), height: 90);

    expect(tester.takeException(), isNull);
  });

  testWidgets('less motion: the skeleton keeps still', (tester) async {
    await pumpLoading(tester, const CbLoadingState(), lessMotion: true);

    // Nothing left animating: settles at once.
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });
}
