import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/text_utils.dart';
import 'package:wyn/core/widgets/restriction_banner.dart';

void main() {
  testWidgets('shows the expiry date, days remaining, and reason', (tester) async {
    final expiresAt = DateTime.now().add(const Duration(days: 3));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RestrictionBanner(reason: 'สแปม', expiresAt: expiresAt),
      ),
    ));

    expect(
      find.textContaining('คุณถูกจำกัดการโพสต์ชั่วคราวจนถึงวันที่ ${dateLabel(expiresAt)}'),
      findsOneWidget,
    );
    expect(find.textContaining('เนื่องจาก: สแปม'), findsOneWidget);
  });

  testWidgets('renders without a reason or expiry (defensive fallback)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RestrictionBanner(reason: null, expiresAt: null)),
    ));

    expect(find.textContaining('คุณถูกจำกัดการโพสต์ชั่วคราว'), findsOneWidget);
  });
}
