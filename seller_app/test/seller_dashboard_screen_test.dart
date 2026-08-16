import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/dashboard/presentation/seller_dashboard_screen.dart';
import 'package:zoky_seller/features/store/data/store.dart';

import 'support/recording_seller_notification_repository.dart';
import 'support/recording_seller_repository.dart';

final _store = Store(
  id: 'store-1',
  ownerId: 'u1',
  name: 'ร้านทดสอบ',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  // See seller_auth_gate_test.dart's comment on why Recording*Repository
  // must be built in setUp(), not inline inside testWidgets.
  late RecordingSellerRepository statsRepository;
  late RecordingSellerRepository emptyBestSellingRepository;
  late RecordingSellerRepository defaultRepository;
  late RecordingSellerNotificationRepository notificationRepository;

  setUp(() {
    statsRepository = RecordingSellerRepository(
      orderCounts: (3, 12),
      salesSummary: (1500.0, 42000.0, 100000.0),
      bestSellingProducts: const [
        ('เสื้อยืด', 20),
        ('กางเกงยีนส์', 15),
      ],
    );
    emptyBestSellingRepository =
        RecordingSellerRepository(bestSellingProducts: const []);
    defaultRepository = RecordingSellerRepository();
    notificationRepository = RecordingSellerNotificationRepository();
  });

  testWidgets('renders order counts, sales summary and best selling list',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerDashboardScreen(
        store: _store,
        sellerRepository: statsRepository,
        notificationRepository: notificationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ร้านทดสอบ'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('฿1,500'), findsOneWidget);
    expect(find.text('฿42,000'), findsOneWidget);
    expect(find.text('฿100,000'), findsOneWidget);
    expect(find.text('เสื้อยืด'), findsOneWidget);
    expect(find.text('ขายแล้ว 20'), findsOneWidget);
    expect(find.text('กางเกงยีนส์'), findsOneWidget);
    expect(find.text('ขายแล้ว 15'), findsOneWidget);
  });

  testWidgets(
      'shows a friendly empty state instead of an empty list when there '
      'are no delivered sales yet', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerDashboardScreen(
        store: _store,
        sellerRepository: emptyBestSellingRepository,
        notificationRepository: notificationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีข้อมูลการขาย'), findsOneWidget);
  });

  testWidgets(
      'shows "เร็ว ๆ นี้" for balance/payout instead of a misleading zero',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerDashboardScreen(
        store: _store,
        sellerRepository: defaultRepository,
        notificationRepository: notificationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('เร็ว ๆ นี้'), findsOneWidget);
    expect(find.text('ยอดคงเหลือ / รอโอน'), findsOneWidget);
  });
}
