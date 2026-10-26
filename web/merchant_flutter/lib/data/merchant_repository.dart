import 'dart:convert';
import 'bridge_transport.dart';

typedef Json = Map<String, dynamic>;
const orderStatuses = {
  'pending_acceptance': 'รอรับ',
  'preparing': 'กำลังเตรียม',
  'ready_for_delivery': 'พร้อมส่ง',
  'out_for_delivery': 'กำลังจัดส่ง',
  'ready_for_pickup': 'พร้อมให้รับ',
  'picked_up': 'ลูกค้ารับแล้ว',
  'delivered': 'สำเร็จ',
  'cancelled': 'ยกเลิก',
};
const paymentStatuses = {
  'pending': 'รอชำระเงิน',
  'submitted': 'รอตรวจสลิป',
  'paid': 'ชำระแล้ว',
  'issue': 'มีปัญหาการชำระเงิน',
  'refunded': 'คืนเงินแล้ว',
};
const nextStatuses = {
  'pending_acceptance': 'preparing',
  'preparing': 'ready_for_delivery',
  'ready_for_delivery': 'out_for_delivery',
};
const nextActions = {
  'pending_acceptance': 'รับออเดอร์',
  'preparing': 'อาหารพร้อมแล้ว',
  'ready_for_delivery': 'เริ่มจัดส่ง',
};

class MerchantException implements Exception {
  const MerchantException(this.message);
  final String message;
}

/// Existing WYNOS JavaScript client owns authentication, account switching,
/// push cleanup and API contracts. Flutter holds no credentials or tokens.
String? orderNextStatus(Json order) => order['fulfillment_type'] == 'pickup'
    ? switch (order['status']) {
        'pending_acceptance' => 'preparing',
        'preparing' => 'ready_for_pickup',
        'ready_for_pickup' => 'picked_up',
        _ => null,
      }
    : nextStatuses[order['status']];
String? orderNextAction(Json order) => order['fulfillment_type'] == 'pickup'
    ? switch (order['status']) {
        'pending_acceptance' => 'รับออเดอร์',
        'preparing' => 'พร้อมให้รับ',
        'ready_for_pickup' => 'ลูกค้ารับแล้ว',
        _ => null,
      }
    : nextActions[order['status']];

abstract class MerchantRepository {
  static const pageSize = 50;
  Stream<void> get orderChanges => const Stream.empty();
  Future<List<Json>> stores();
  Future<bool> hasRole(String storeId, List<String> roles);
  Future<List<Json>> menu(String storeId);
  Future<List<Json>> orders(String storeId, String status, int offset);
  Future<Json> report(String storeId);
  Future<Json> quality(String storeId) async => {'available': false};
  Future<Json> campaigns(String storeId);
  Future<void> saveMenu(String storeId, Json values, {String? id});
  Future<void> saveStore(String storeId, Json values);
  Future<void> cancelStoreOrder(
    String storeId,
    String orderId,
    bool refund,
    String note,
  ) async => throw const MerchantException(
    'บันทึกไม่สำเร็จ กรุณารีเฟรชข้อมูลก่อนลองอีกครั้ง',
  );
  Future<void> setFulfillment(String storeId, Json values) async =>
      throw const MerchantException(
        'บันทึกไม่สำเร็จ กรุณารีเฟรชข้อมูลก่อนลองอีกครั้ง',
      );
  Future<void> resolveCancel(
    String storeId,
    String orderId,
    bool approve,
    bool refund,
  ) async => throw const MerchantException(
    'บันทึกไม่สำเร็จ กรุณารีเฟรชข้อมูลก่อนลองอีกครั้ง',
  );
  Future<Json?> pickRefundSlip(String storeId, String orderId) async => null;
  Future<void> markRefunded(
    String storeId,
    String orderId,
    String imagePath,
  ) async => throw const MerchantException(
    'บันทึกไม่สำเร็จ กรุณารีเฟรชข้อมูลก่อนลองอีกครั้ง',
  );
  Future<void> transition(
    String storeId,
    String orderId,
    String status, {
    String? note,
    int? etaMinutes,
  });
  Future<void> payment(
    String storeId,
    String orderId,
    String status, {
    String? note,
    bool manualConfirmation = false,
  });
  Future<Json?> pickDeliveryPhoto(String storeId, String orderId);
  Future<void> releaseDeliveryPhoto(
    String storeId,
    String orderId,
    String imagePath,
  ) async {}
  Future<void> completeDelivery(
    String storeId,
    String orderId,
    String method,
    String imagePath, {
    String? locationNote,
    bool cashReceived = false,
  });
  Future<String?> signedUrl(String storeId, String orderId, String kind);
  Future<void> subscribe(String storeId);
  Future<Json> pushStatus();
  Future<Json> pushEnable();
  Future<Json> pushDisable();
  Future<void> createCampaign(String storeId, String name, double discount);
  Future<void> setCampaignActive(String storeId, String id, bool active);
  Future<void> signOut();
}

class BridgeMerchantRepository extends MerchantRepository {
  BridgeMerchantRepository(this.transport);
  final BridgeTransport transport;
  @override
  Stream<void> get orderChanges => transport.orderChanges;
  Future<dynamic> call(String method, [Json args = const {}]) async {
    final decoded = jsonDecode(
      await transport.request(method, jsonEncode(args)),
    );
    if (decoded is! Map || decoded['ok'] != true) {
      throw MerchantException(
        decoded is Map && decoded['error'] is String
            ? decoded['error'] as String
            : 'การเชื่อมต่อระบบร้านไม่สมบูรณ์',
      );
    }
    return decoded['data'];
  }

  List<Json> rows(dynamic data) =>
      (data as List).map((e) => Json.from(e as Map)).toList();
  Json object(dynamic data) => Json.from(data as Map);
  @override
  Future<List<Json>> stores() async => rows(await call('stores'));
  @override
  Future<bool> hasRole(String storeId, List<String> roles) async =>
      await call('hasRole', {'storeId': storeId, 'roles': roles}) == true;
  @override
  Future<List<Json>> menu(String storeId) async =>
      rows(await call('menu', {'storeId': storeId}));
  @override
  Future<List<Json>> orders(String storeId, String status, int offset) async =>
      rows(
        await call('orders', {
          'storeId': storeId,
          'status': status,
          'offset': offset,
        }),
      );
  @override
  Future<Json> report(String storeId) async =>
      object(await call('report', {'storeId': storeId}));
  @override
  Future<Json> quality(String storeId) async =>
      object(await call('quality', {'storeId': storeId}));
  @override
  Future<Json> campaigns(String storeId) async =>
      object(await call('campaigns', {'storeId': storeId}));
  @override
  Future<void> saveMenu(String storeId, Json values, {String? id}) async {
    await call('saveMenu', {'storeId': storeId, 'values': values, 'id': ?id});
  }

  @override
  Future<void> saveStore(String storeId, Json values) async {
    await call('saveStore', {'storeId': storeId, 'values': values});
  }

  @override
  Future<void> cancelStoreOrder(
    String storeId,
    String orderId,
    bool refund,
    String note,
  ) async {
    await call('cancelStoreOrder', {
      'storeId': storeId,
      'orderId': orderId,
      'refund': refund,
      'note': note,
    });
  }

  @override
  Future<void> setFulfillment(String storeId, Json values) async {
    await call('setFulfillment', {'storeId': storeId, 'values': values});
  }

  @override
  Future<void> resolveCancel(
    String storeId,
    String orderId,
    bool approve,
    bool refund,
  ) async {
    await call('resolveCancel', {
      'storeId': storeId,
      'orderId': orderId,
      'approve': approve,
      'refund': refund,
    });
  }

  @override
  Future<Json?> pickRefundSlip(String storeId, String orderId) async {
    final data = await call('pickRefundSlip', {
      'storeId': storeId,
      'orderId': orderId,
    });
    return data == null ? null : object(data);
  }

  @override
  Future<void> markRefunded(
    String storeId,
    String orderId,
    String imagePath,
  ) async {
    await call('markRefunded', {
      'storeId': storeId,
      'orderId': orderId,
      'imagePath': imagePath,
    });
  }

  @override
  Future<void> transition(
    String storeId,
    String orderId,
    String status, {
    String? note,
    int? etaMinutes,
  }) async {
    await call('transition', {
      'storeId': storeId,
      'orderId': orderId,
      'status': status,
      'note': ?note,
      'etaMinutes': ?etaMinutes,
    });
  }

  @override
  Future<void> payment(
    String storeId,
    String orderId,
    String status, {
    String? note,
    bool manualConfirmation = false,
  }) async {
    await call('payment', {
      'storeId': storeId,
      'orderId': orderId,
      'status': status,
      'note': ?note,
      if (manualConfirmation) 'manualConfirmation': true,
    });
  }

  @override
  Future<Json?> pickDeliveryPhoto(String storeId, String orderId) async {
    final data = await call('pickDeliveryPhoto', {
      'storeId': storeId,
      'orderId': orderId,
    });
    return data == null ? null : object(data);
  }

  @override
  Future<void> releaseDeliveryPhoto(
    String storeId,
    String orderId,
    String imagePath,
  ) async {
    await call('releaseDeliveryPhoto', {
      'storeId': storeId,
      'orderId': orderId,
      'imagePath': imagePath,
    });
  }

  @override
  Future<void> completeDelivery(
    String storeId,
    String orderId,
    String method,
    String imagePath, {
    String? locationNote,
    bool cashReceived = false,
  }) async {
    await call('completeDelivery', {
      'storeId': storeId,
      'orderId': orderId,
      'method': method,
      'imagePath': imagePath,
      'locationNote': ?locationNote,
      'cashReceived': cashReceived,
    });
  }

  @override
  Future<String?> signedUrl(
    String storeId,
    String orderId,
    String kind,
  ) async =>
      await call('signedUrl', {
            'storeId': storeId,
            'orderId': orderId,
            'kind': kind,
          })
          as String?;
  @override
  Future<void> subscribe(String storeId) async {
    await call('subscribe', {'storeId': storeId});
  }

  @override
  Future<Json> pushStatus() async => object(await call('pushStatus'));
  @override
  Future<Json> pushEnable() async => object(await call('pushEnable'));
  @override
  Future<Json> pushDisable() async => object(await call('pushDisable'));
  @override
  Future<void> createCampaign(
    String storeId,
    String name,
    double discount,
  ) async {
    await call('createCampaign', {
      'storeId': storeId,
      'name': name,
      'discount': discount,
    });
  }

  @override
  Future<void> setCampaignActive(String storeId, String id, bool active) async {
    await call('setCampaignActive', {
      'storeId': storeId,
      'id': id,
      'active': active,
    });
  }

  @override
  Future<void> signOut() async {
    await call('signOut');
  }
}

String errorMessage(Object e) {
  if (e is MerchantException) return e.message;
  return 'เชื่อมต่อหรือบันทึกไม่สำเร็จ กรุณารีเฟรชข้อมูลก่อนลองอีกครั้ง';
}
