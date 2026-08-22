import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/text_utils.dart';
import 'package:wyn/features/auth/presentation/account_restricted_screen.dart';

void main() {
  testWidgets('Suspend variant shows the temporary headline, expiry date, and reason',
      (tester) async {
    final expiresAt = DateTime.now().add(const Duration(days: 3));
    var acknowledged = false;

    await tester.pumpWidget(MaterialApp(
      home: AccountRestrictedScreen(
        isBanned: false,
        reason: 'สแปม',
        expiresAt: expiresAt,
        onAcknowledge: () => acknowledged = true,
      ),
    ));

    expect(find.text('บัญชีของคุณถูกระงับชั่วคราว'), findsOneWidget);
    expect(find.text('เหตุผล: สแปม'), findsOneWidget);
    expect(
      find.textContaining('ระงับถึงวันที่ ${dateLabel(expiresAt)}'),
      findsOneWidget,
    );
    // Ban-only copy must not leak into the Suspend variant.
    expect(find.text('การอุทธรณ์ยังไม่เปิดให้ใช้งานในแอปขณะนี้'), findsNothing);

    await tester.tap(find.text('ตกลง'));
    expect(acknowledged, isTrue);
  });

  testWidgets('Ban variant shows the permanent headline and the no-appeal copy, no expiry',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AccountRestrictedScreen(
        isBanned: true,
        reason: 'ละเมิดกฎ',
        expiresAt: null,
        onAcknowledge: () {},
      ),
    ));

    expect(find.text('บัญชีของคุณถูกระงับถาวร'), findsOneWidget);
    expect(find.text('เหตุผล: ละเมิดกฎ'), findsOneWidget);
    expect(find.text('การอุทธรณ์ยังไม่เปิดให้ใช้งานในแอปขณะนี้'), findsOneWidget);
    expect(find.textContaining('เมื่อครบกำหนดคุณจะกลับมาใช้งานได้ตามปกติ'), findsNothing);
  });
}
