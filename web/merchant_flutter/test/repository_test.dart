import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/bridge_transport.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';

class RecordingTransport implements BridgeTransport {
  String? method;
  Json? args;
  String response = '{"ok":true,"data":null}';
  @override
  Stream<void> get orderChanges => const Stream.empty();
  @override
  Future<String> request(String name, String payload) async {
    method = name;
    args = Json.from(jsonDecode(payload) as Map);
    return response;
  }

  @override
  void dispose() {}
}

void main() {
  test(
    'payment and delivery delegate to existing web services with store context',
    () async {
      final transport = RecordingTransport();
      final repo = BridgeMerchantRepository(transport);
      await repo.payment('store-a', 'order-a', 'paid', note: 'ตรวจแล้ว');
      expect(transport.method, 'payment');
      expect(transport.args, {
        'storeId': 'store-a',
        'orderId': 'order-a',
        'status': 'paid',
        'note': 'ตรวจแล้ว',
      });
      await repo.completeDelivery(
        'store-a',
        'order-a',
        'dropoff',
        'delivery/order-a/photo.jpg',
        locationNote: 'หน้าประตู',
      );
      expect(transport.method, 'completeDelivery');
      expect(transport.args!['imagePath'], 'delivery/order-a/photo.jpg');
      expect(transport.args!['locationNote'], 'หน้าประตู');
    },
  );
  test(
    'bridge errors reject writes and never become a successful null response',
    () async {
      final transport = RecordingTransport()
        ..response = '{"ok":false,"error":"ไม่มีสิทธิ์จัดการร้านนี้"}';
      expect(
        () => BridgeMerchantRepository(
          transport,
        ).saveStore('store-a', {'is_open': true}),
        throwsA(isA<MerchantException>()),
      );
    },
  );
  test(
    'order paging and evidence lookup always carry selected store',
    () async {
      final transport = RecordingTransport()
        ..response = '{"ok":true,"data":[]}';
      final repo = BridgeMerchantRepository(transport);
      await repo.orders('store-a', 'preparing', 50);
      expect(transport.args, {
        'storeId': 'store-a',
        'status': 'preparing',
        'offset': 50,
      });
      transport.response =
          '{"ok":true,"data":"https://example.invalid/signed"}';
      expect(
        await repo.signedUrl('store-a', 'order-a', 'proof'),
        'https://example.invalid/signed',
      );
      expect(transport.args, {
        'storeId': 'store-a',
        'orderId': 'order-a',
        'kind': 'proof',
      });
    },
  );
  test(
    'menu patch delegates only changed values so existing options survive',
    () async {
      final transport = RecordingTransport();
      await BridgeMerchantRepository(
        transport,
      ).saveMenu('store-a', {'name': 'ข้าวผัด', 'price': 90}, id: 'menu-a');
      expect(transport.args, {
        'storeId': 'store-a',
        'id': 'menu-a',
        'values': {'name': 'ข้าวผัด', 'price': 90},
      });
    },
  );
}
