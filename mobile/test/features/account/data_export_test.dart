// "Download my data": the ZIP comes into a temporary file, with how much has
// come (the server doesn't say the total) and "Cancel"; then Save or Share.
// However the sheet closes, the file goes; a new export or a sign-out also
// deletes the copies Share left. A few downloads an hour: past them, how
// long to wait.
import 'dart:async';
import 'dart:io';

import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/account/account.dart';
import 'package:collarbell/features/account/account_labels.dart';
import 'package:collarbell/features/account/delete_account_screen.dart';
import 'package:collarbell/features/account/export_files.dart';
import 'package:collarbell/l10n/app_localizations.dart';
import 'package:collarbell/l10n/app_localizations_en.dart';
import 'package:collarbell/l10n/app_localizations_ru.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

ApiException tooOften([Duration? wait]) => ApiException(
  ApiErrorKind.tooManyRequests,
  statusCode: 429,
  retryAfter: wait,
);

void main() {
  late FakeAccountRepository account;
  late FakeExportFiles files;

  setUp(() {
    account = FakeAccountRepository();
    files = FakeExportFiles();
  });

  /// Opens More and taps "Download my data". While it downloads the sheet's
  /// bar keeps moving, so this pumps frames rather than waiting for calm.
  Future<void> openExport(WidgetTester tester, {String language = 'en'}) async {
    await pumpApp(
      tester,
      location: AppRoutes.more,
      language: language,
      overrides: fakeRepositories(account: account, exportFiles: files),
    );
    final tile = find.byKey(const ValueKey('downloadData'));
    await tester.scrollUntilVisible(tile, 300);
    await tapAndWait(tester, tile);
  }

  testWidgets('shows how much has come, then Save or Share; the file goes '
      'when the sheet closes', (tester) async {
    account
      ..exportProgress = [2500000]
      ..exportGate = Completer<void>();
    await openExport(tester);

    expect(find.text('Downloaded: 2.5 MB'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(files.folders, 1);

    account.exportGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Ready: 24.5 MB'), findsOneWidget);
    expect(
      find.text("It has your pets' documents: keep it somewhere safe."),
      findsOneWidget,
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(files.shared.single.name, 'collarbell-export-2026-10-06.zip');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(files.saved, hasLength(1));
    expect(find.text('Saved.'), findsOneWidget);

    expect(files.clears, 0);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Ready: 24.5 MB'), findsNothing);
    expect(files.clears, 1);
  });

  testWidgets('Cancel stops the download, and what came goes', (tester) async {
    account.exportGate = Completer<void>();
    await openExport(tester);
    expect(find.text('Preparing the file…'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Preparing the file…'), findsNothing);
    expect(account.exportCancel!.isCancelled, isTrue);
    expect(files.clears, 1);
  });

  testWidgets('too many this hour: how long to wait, and no Try again', (
    tester,
  ) async {
    account.exportError = tooOften(const Duration(seconds: 690));
    await openExport(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        "You've downloaded your data several times this hour. Try again in "
        '12 minutes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsNothing);
  });

  testWidgets('no connection: it says so; Try again downloads again', (
    tester,
  ) async {
    account.exportError = networkError;
    await openExport(tester);
    await tester.pumpAndSettle();

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    account.exportError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Ready: 24.5 MB'), findsOneWidget);
    expect(account.exports, 2);
  });

  testWidgets('a file over 25 MB goes by Share only', (tester) async {
    account.exportBytes = 26 * 1000 * 1000;
    await openExport(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ready: 26.0 MB'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(
      find.text(
        'The file is large: save it with “Share”, e.g. to Files or Drive.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(files.shared, hasLength(1));
  });

  testWidgets('Share failed: it says so, and why it may have', (tester) async {
    account.exportBytes = 150 * 1000 * 1000;
    files.shareError = PlatformException(code: 'share_failed');
    await openExport(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Couldn't share the file. Check that the phone has free space and "
        'try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a small export in kilobytes, not "0.0 MB"', (tester) async {
    account
      ..exportBytes = 4800
      ..exportProgress = [2500]
      ..exportGate = Completer<void>();
    await openExport(tester, language: 'ru');

    expect(find.text('Скачано: 3 КБ'), findsOneWidget);
    account.exportGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Готово: 5 КБ'), findsOneWidget);
  });

  testWidgets('saving cancelled says nothing; saving failed points to Share', (
    tester,
  ) async {
    files.saveAnswer = false;
    await openExport(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved.'), findsNothing);

    files.saveError = PlatformException(code: 'explorer_not_found');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save the file. Try “Share”."), findsOneWidget);
  });

  testWidgets('in Russian: megabytes with a comma', (tester) async {
    account
      ..exportProgress = [2500000]
      ..exportGate = Completer<void>();
    await openExport(tester, language: 'ru');

    expect(find.text('Скачано: 2,5 МБ'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    account.exportGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Готово: 24,5 МБ'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(find.text('Поделиться'), findsOneWidget);
  });

  testWidgets('the delete screen offers it first, and stays under it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: AppRoutes.deleteAccount,
      size: const Size(390, 2600),
      overrides: fakeRepositories(account: account, exportFiles: files),
    );

    await tapVisible(tester, find.byKey(const ValueKey('exportFirst')));
    expect(find.text('Ready: 24.5 MB'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(files.clears, 1);
  });

  group('how long to wait', () {
    test('whole minutes, rounded up; without Retry-After, later', () {
      final en = AppLocalizationsEn();
      final ru = AppLocalizationsRu();
      String said(Duration? wait, [AppLocalizations? l10n]) =>
          dataExportErrorMessage(tooOften(wait), l10n ?? en);

      expect(said(const Duration(seconds: 30)), endsWith('in 1 minute.'));
      expect(said(const Duration(seconds: 61)), endsWith('in 2 minutes.'));
      expect(said(null), endsWith('Try again later.'));
      expect(
        said(const Duration(minutes: 21), ru),
        endsWith('Попробуйте через 21 минуту.'),
      );
      expect(
        said(const Duration(minutes: 3), ru),
        endsWith('Попробуйте через 3 минуты.'),
      );
      expect(
        said(const Duration(minutes: 45), ru),
        endsWith('Попробуйте через 45 минут.'),
      );
      // Anything else: the usual words.
      expect(
        dataExportErrorMessage(networkError, en),
        "Can't reach the server. Check your connection and try again.",
      );
    });
  });

  group('the export files on the phone', () {
    late Directory temp;
    final files = DeviceExportFiles();

    setUp(() {
      temp = Directory.systemTemp.createTempSync('collarbell_files_test');
      // path_provider's "temporary folder" is this one.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => temp.path,
          );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      temp.deleteSync(recursive: true);
    });

    File put(String path) => File('${temp.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync('PK');

    test('the sheet closing deletes the download; a copy Share made stays '
        '(another app may still read it)', () async {
      final download = put('data_export/collarbell-export-2026-10-06.zip');
      final shared = put('share_plus/collarbell-export-2026-10-06.zip');

      await files.clear();

      expect(download.existsSync(), isFalse);
      expect(shared.existsSync(), isTrue);
    });

    test('a new export, or a sign-out, deletes every copy: one cut off '
        'midway, and those Share made; nothing else', () async {
      final cut = put('data_export/collarbell-export-2026-10-05.zip');
      final shared = put('share_plus/collarbell-export-2026-10-05.zip');
      final otherShared = put('share_plus/invite.txt');

      final folder = await files.freshFolder();

      expect(cut.existsSync(), isFalse);
      expect(shared.existsSync(), isFalse);
      expect(otherShared.existsSync(), isTrue);
      expect(folder.path, '${temp.path}/data_export');
      expect(folder.existsSync(), isTrue);
      expect(folder.listSync(), isEmpty);

      put('share_plus/collarbell-export-2026-10-06.zip');
      await files.clearAll();
      expect(Directory('${temp.path}/share_plus').listSync(), hasLength(1));
      expect(folder.existsSync(), isFalse);
    });

    test('"Save" takes up to 25 MB', () {
      const file = ExportFile(path: '/x', name: 'x.zip', bytes: 25000000);
      expect(file.bytes <= exportSaveLimit, isTrue);
      expect(file.bytes + 1 <= exportSaveLimit, isFalse);
    });
  });
}
