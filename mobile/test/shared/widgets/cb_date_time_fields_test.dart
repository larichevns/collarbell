// The date and time pickers sit above the screen. If the screen closes while
// one is open (review probe "busy_picker"), the value picked afterwards has
// nowhere to go and must be dropped quietly.
import 'package:collarbell/shared/widgets/cb_date_field.dart';
import 'package:collarbell/shared/widgets/cb_time_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump.dart';

/// A screen whose [field] can be taken away while its picker is open.
class _Removable extends StatefulWidget {
  const _Removable({required this.field});

  final Widget field;

  @override
  State<_Removable> createState() => _RemovableState();
}

class _RemovableState extends State<_Removable> {
  var _shown = true;

  /// Closes the field, as when its screen goes away.
  void removeField() => setState(() => _shown = false);

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: _shown ? widget.field : const SizedBox.shrink());
}

void main() {
  /// Opens the field's picker, removes the field behind it, then confirms.
  Future<void> pickAfterTheFieldIsGone(WidgetTester tester) async {
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    // The picker is a dialog above the screen: the field goes, it stays.
    tester.state<_RemovableState>(find.byType(_Removable)).removeField();
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('a date picked after the field is gone is dropped', (
    tester,
  ) async {
    var changes = 0;
    await pumpScreen(
      tester,
      _Removable(
        field: CbDateField(
          label: 'Date',
          value: null,
          onChanged: (_) => changes++,
        ),
      ),
    );

    await pickAfterTheFieldIsGone(tester);

    expect(tester.takeException(), isNull);
    expect(changes, 0);
  });

  testWidgets('a time picked after the field is gone is dropped', (
    tester,
  ) async {
    var changes = 0;
    await pumpScreen(
      tester,
      _Removable(
        field: CbTimeField(
          label: 'Time',
          value: null,
          onChanged: (_) => changes++,
        ),
      ),
    );

    await pickAfterTheFieldIsGone(tester);

    expect(tester.takeException(), isNull);
    expect(changes, 0);
  });
}
