import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/text_utils.dart';
import 'package:wyn/features/auth/presentation/account_restricted_screen.dart';
import 'package:wyn/features/moderation/data/appeal_status.dart';

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
    // No actionId passed -- the appeal section must not render at all
    // (same defaulting shape as RestrictionBanner).
    expect(find.text('อุทธรณ์'), findsNothing);

    await tester.tap(find.text('ตกลง'));
    expect(acknowledged, isTrue);
  });

  testWidgets('Ban variant shows the permanent headline, reason, no expiry',
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
    expect(find.textContaining('เมื่อครบกำหนดคุณจะกลับมาใช้งานได้ตามปกติ'), findsNothing);
  });

  // WYN-030 -- the appeal section, gated on actionId being non-null and
  // switching on appealStatus. Ban and Suspend share this exact same
  // logic (no isBanned-only gating any more), so one variant (Ban) is
  // enough to cover all 3 reachable states.
  group('appeal section (WYN-030)', () {
    testWidgets('appealStatus none shows an อุทธรณ์ button that calls onAppeal',
        (tester) async {
      var appealTapped = false;

      await tester.pumpWidget(MaterialApp(
        home: AccountRestrictedScreen(
          isBanned: true,
          reason: 'ละเมิดกฎ',
          expiresAt: null,
          onAcknowledge: () {},
          actionId: 'action-1',
          appealStatus: AppealStatus.none,
          onAppeal: () async => appealTapped = true,
        ),
      ));

      expect(find.text('อุทธรณ์'), findsOneWidget);
      await tester.tap(find.text('อุทธรณ์'));
      expect(appealTapped, isTrue);
    });

    testWidgets('appealStatus pending shows the under-review message, no button',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AccountRestrictedScreen(
          isBanned: true,
          reason: 'ละเมิดกฎ',
          expiresAt: null,
          onAcknowledge: () {},
          actionId: 'action-1',
          appealStatus: AppealStatus.pending,
        ),
      ));

      expect(find.text('คุณได้ส่งอุทธรณ์แล้ว อยู่ระหว่างการตรวจสอบ'), findsOneWidget);
      expect(find.text('อุทธรณ์'), findsNothing);
    });

    testWidgets('appealStatus rejected shows the rejected message, no button',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AccountRestrictedScreen(
          isBanned: true,
          reason: 'ละเมิดกฎ',
          expiresAt: null,
          onAcknowledge: () {},
          actionId: 'action-1',
          appealStatus: AppealStatus.rejected,
        ),
      ));

      expect(find.text('อุทธรณ์ของคุณถูกปฏิเสธแล้ว'), findsOneWidget);
      expect(find.text('อุทธรณ์'), findsNothing);
    });
  });
}
