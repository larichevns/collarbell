import 'dart:io';
import 'dart:ui' as ui;

import 'package:collarbell/app/app.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:collarbell/features/files/media_picker.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/onboarding/onboarding.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/shared/widgets/cb_date_field.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps frames until [finder] matches. Network calls never "settle", so
/// pumpAndSettle can't be used for screens that load data.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  if (!await appears(tester, finder, timeout)) {
    throw TestFailure('Timed out after $timeout waiting for $finder');
  }
}

Future<bool> appears(
  WidgetTester tester,
  Finder finder,
  Duration timeout,
) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Lets route transitions finish before a screenshot.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Marks the onboarding as seen for the developer account of [email]: an
/// account with no pets would get it on Home after signing in. These tests
/// are about other screens; the onboarding has its widget tests.
Future<void> skipOnboarding(SharedPreferences prefs, String email) =>
    prefs.setBool(
      OnboardingTurn.keyFor(
        DevAuthRepository.uidForEmail(DevAuthRepository.normalizeEmail(email)),
      ),
      true,
    );

/// The Pets tab in the bottom navigation bar.
Finder petsTab() => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text('Pets'),
);

/// The Today tab in the bottom navigation bar.
Finder todayTab() => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text('Today'),
);

/// Opens the date field labelled [label] and types [date] in the date
/// picker's input mode, as a user would.
Future<void> pickDate(WidgetTester tester, String label, DateTime date) async {
  // The field itself, not the clear button inside it.
  final dateField = find
      .descendant(
        of: find.widgetWithText(CbDateField, label),
        matching: find.byType(InkWell),
      )
      .first;
  await tester.ensureVisible(dateField);
  await settle(tester);
  await tester.tap(dateField);
  await pumpUntil(tester, find.byTooltip('Switch to input'));
  await tester.tap(find.byTooltip('Switch to input'));
  await settle(tester);
  final dialog = find.byType(DatePickerDialog);
  final localizations = MaterialLocalizations.of(tester.element(dialog));
  await tester.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)),
    localizations.formatCompactDate(date),
  );
  await tester.tap(find.text('OK'));
  await settle(tester);
}

/// Scrolls [scrollable] until [finder] is built and on screen.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  required Finder scrollable,
}) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: scrollable);
  await tester.ensureVisible(finder);
  await settle(tester);
}

/// The scrolling list inside the widget [type], e.g. a tab.
Finder scrollableIn(Type type) => find
    .descendant(of: find.byType(type), matching: find.byType(Scrollable))
    .first;

/// An image that has finished loading.
final loadedImage = find.byWidgetPredicate(
  (widget) => widget is RawImage && widget.image != null,
);

/// The text field under the label [label].
Finder field(String label) => find.descendant(
  of: find.widgetWithText(CbTextField, label),
  matching: find.byType(TextFormField),
);

Future<void> hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester);
}

/// Deletes every pet of the test account through the app's own repository.
Future<void> deleteAllPets(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CollarbellApp)),
  );
  final pets = container.read(petsRepositoryProvider);
  for (final pet in await pets.getPets()) {
    await pets.deletePet(pet.id);
  }
}

/// Returns pictures drawn at runtime: a pet photo for the pet's photo, a
/// passport page for pages.
class DrawnPagePicker implements MediaPicker {
  @override
  Future<PickedMedia?> takePhoto() => drawPassportPage();

  @override
  Future<PickedMedia?> pickPhoto() => drawPetPhoto();

  @override
  Future<List<PickedMedia>> pickPhotos({int? limit}) async => [
    await drawPassportPage(),
  ];

  @override
  Future<PickedMedia?> pickPdf() async => null;

  @override
  Future<List<PickedMedia>?> scanPages({required int maxPages}) async => [
    await drawPassportPage(),
  ];

  @override
  Future<List<PickedMedia>> prepareScans(List<PickedMedia> pages) async =>
      pages;

  @override
  Future<void> deletePicked(List<PickedMedia> media) async {
    for (final item in media) {
      final file = File(item.path);
      if (file.existsSync()) await file.delete();
    }
  }
}

/// Draws a cat's head on a warm background, like a pet photo.
Future<PickedMedia> drawPetPhoto() async {
  const size = 800.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  Paint paint(int color) => Paint()..color = Color(color);

  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), paint(0xFFF2C894));
  for (final ear in [
    [const Offset(230, 330), const Offset(270, 130), const Offset(380, 260)],
    [const Offset(570, 330), const Offset(530, 130), const Offset(420, 260)],
  ]) {
    canvas.drawPath(Path()..addPolygon(ear, true), paint(0xFFC0682A));
  }
  canvas.drawCircle(const Offset(400, 440), 230, paint(0xFFD9813C)); // head
  canvas.drawCircle(const Offset(320, 410), 30, paint(0xFF2B3135)); // eyes
  canvas.drawCircle(const Offset(480, 410), 30, paint(0xFF2B3135));
  canvas.drawCircle(const Offset(400, 500), 22, paint(0xFFE89BA1)); // nose
  return savePng(recorder, size, size, 'pet-photo.png');
}

/// Draws something that looks like a passport page.
Future<PickedMedia> drawPassportPage() async {
  const width = 900.0;
  const height = 1200.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  void box(double x, double y, double w, double h, int color) =>
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = Color(color));

  box(0, 0, width, height, 0xFFF4EFDF); // paper
  box(0, 0, width, 140, 0xFF1F3A93); // blue header band
  box(60, 200, 240, 300, 0xFFB7C4D6); // photo box
  for (var line = 0; line < 12; line++) {
    final y = 220.0 + line * 70;
    box(340, y, line.isEven ? 480 : 380, 18, 0xFF8A8A8A); // printed lines
  }
  box(60, 1040, 780, 4, 0xFF1F3A93); // signature line

  return savePng(recorder, width, height, 'passport-page.png');
}

/// Saves the drawing as a PNG in the temporary directory.
Future<PickedMedia> savePng(
  ui.PictureRecorder recorder,
  double width,
  double height,
  String name,
) async {
  final image = await recorder.endRecording().toImage(
    width.toInt(),
    height.toInt(),
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(
    '${Directory.systemTemp.path}/'
    'collarbell-${DateTime.now().microsecondsSinceEpoch}-$name',
  );
  await file.writeAsBytes(png!.buffer.asUint8List());
  return PickedMedia(path: file.path, name: name);
}
