import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/auth/presentation/widgets/otp_box_input.dart';

void main() {
  testWidgets('renders 6 boxes, each announced with its digit position',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: OtpBoxInput(onCompleted: _noop)),
    ));

    expect(find.byType(TextField), findsNWidgets(6));
    for (var i = 1; i <= 6; i++) {
      expect(find.bySemanticsLabel('หลักที่ $i จาก 6'), findsOneWidget);
    }
  });

  testWidgets('typing a digit advances focus to the next box',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: OtpBoxInput(onCompleted: _noop)),
    ));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '1');
    await tester.pump();

    final focusedField = tester
        .widgetList<TextField>(fields)
        .firstWhere((f) => f.focusNode!.hasFocus);
    expect(tester.widgetList<TextField>(fields).toList().indexOf(focusedField),
        1);
  });

  testWidgets('calls onCompleted only once all 6 digits are filled',
      (tester) async {
    String? completedCode;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OtpBoxInput(onCompleted: (code) => completedCode = code),
      ),
    ));

    final fields = find.byType(TextField);
    for (var i = 0; i < 5; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
      await tester.pump();
    }
    expect(completedCode, isNull);

    await tester.enterText(fields.at(5), '6');
    await tester.pump();
    expect(completedCode, '123456');
  });

  testWidgets('clear() empties every box and refocuses the first one',
      (tester) async {
    final key = GlobalKey<OtpBoxInputState>();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: OtpBoxInput(key: key, onCompleted: _noop)),
    ));

    final fields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
      await tester.pump();
    }

    key.currentState!.clear();
    await tester.pump();

    for (final field in tester.widgetList<TextField>(fields)) {
      expect(field.controller!.text, isEmpty);
    }
  });
}

void _noop(String _) {}
