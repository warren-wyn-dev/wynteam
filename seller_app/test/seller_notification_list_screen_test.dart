import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/notification/data/seller_notification.dart';
import 'package:zoky_seller/features/notification/presentation/seller_notification_list_screen.dart';
import 'package:zoky_seller/features/order/presentation/seller_order_detail_screen.dart';

import 'support/recording_seller_notification_repository.dart';
import 'support/recording_seller_repository.dart';

void main() {
  // Every RecordingXRepository is built once per test in setUp(), never
  // inline inside a testWidgets callback -- see
  // seller_auth_gate_test.dart's comment for why (ZOKY-002).
  late RecordingSellerRepository sellerRepo;
  late RecordingSellerNotificationRepository emptyRepo;
  late RecordingSellerNotificationRepository newOrderRepo;
  late RecordingSellerNotificationRepository allTypesRepo;
  late RecordingSellerNotificationRepository mixedReadRepo;

  final now = DateTime.now();

  SellerNotification newOrderNotification({bool isRead = false}) => SellerNotification(
        id: 'n-new-order',
        type: SellerNotificationType.newOrder,
        buyerUsername: 'buyer_user',
        buyerDisplayName: 'ผู้ซื้อทดสอบ',
        orderId: 'order-1',
        isRead: isRead,
        createdAt: now.subtract(const Duration(minutes: 3)),
      );

  SellerNotification orderCancelledNotification({bool isRead = false}) => SellerNotification(
        id: 'n-order-cancelled',
        type: SellerNotificationType.orderCancelled,
        buyerUsername: 'buyer_user',
        orderId: 'order-2',
        isRead: isRead,
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

  setUp(() {
    sellerRepo = RecordingSellerRepository();
    emptyRepo = RecordingSellerNotificationRepository(notifications: []);
    newOrderRepo = RecordingSellerNotificationRepository(
      notifications: [newOrderNotification()],
    );
    allTypesRepo = RecordingSellerNotificationRepository(notifications: [
      newOrderNotification(),
      orderCancelledNotification(),
    ]);
    mixedReadRepo = RecordingSellerNotificationRepository(notifications: [
      newOrderNotification(isRead: false),
      orderCancelledNotification(isRead: true),
    ]);
  });

  Widget buildScreen(RecordingSellerNotificationRepository notificationRepository) =>
      MaterialApp(
        home: SellerNotificationListScreen(
          notificationRepository: notificationRepository,
          sellerRepository: sellerRepo,
        ),
      );

  testWidgets('shows type-specific Thai messages for both notification types',
      (tester) async {
    await tester.pumpWidget(buildScreen(allTypesRepo));
    await tester.pumpAndSettle();

    expect(find.text('ผู้ซื้อทดสอบ สั่งซื้อสินค้าจากร้านของคุณ'), findsOneWidget);
    expect(find.text('@buyer_user ยกเลิกคำสั่งซื้อที่ร้านของคุณ'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no notifications',
      (tester) async {
    await tester.pumpWidget(buildScreen(emptyRepo));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีการแจ้งเตือน'), findsOneWidget);
  });

  testWidgets('calls markAllAsRead once after the initial fetch succeeds',
      (tester) async {
    await tester.pumpWidget(buildScreen(newOrderRepo));
    await tester.pumpAndSettle();

    expect(newOrderRepo.markAllAsReadCalls, 1);
  });

  testWidgets(
      'a row that was unread at fetch time is highlighted and a row that '
      'was already read is not', (tester) async {
    await tester.pumpWidget(buildScreen(mixedReadRepo));
    await tester.pumpAndSettle();

    final unreadContainer = tester.widget<Container>(
      find.ancestor(
        of: find.text('ผู้ซื้อทดสอบ สั่งซื้อสินค้าจากร้านของคุณ'),
        matching: find.byType(Container),
      ),
    );
    final readContainer = tester.widget<Container>(
      find.ancestor(
        of: find.text('@buyer_user ยกเลิกคำสั่งซื้อที่ร้านของคุณ'),
        matching: find.byType(Container),
      ),
    );
    expect(unreadContainer.color, isNotNull);
    expect(readContainer.color, isNull);
  });

  testWidgets('tapping a new_order notification opens SellerOrderDetailScreen',
      (tester) async {
    await tester.pumpWidget(buildScreen(newOrderRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ผู้ซื้อทดสอบ สั่งซื้อสินค้าจากร้านของคุณ'));
    await tester.pumpAndSettle();
    tester.takeException();

    final screen =
        tester.widget<SellerOrderDetailScreen>(find.byType(SellerOrderDetailScreen));
    expect(screen.orderId, 'order-1');
  });
}
