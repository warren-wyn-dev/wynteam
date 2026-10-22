import 'package:zoky_merchant/data/merchant_repository.dart';

class FakeRepository extends MerchantRepository {
  bool access = true, manager = true, failReads = false, failWrites = false;
  int writes = 0, orderReads = 0;
  List<Json> storeRows = [
    {
      'id': 'store-1',
      'name': 'ร้านทดสอบ',
      'phone': '0812345678',
      'address': 'มหาสารคาม',
      'is_open': true,
      'is_published': true,
    },
  ];
  List<Json> menuRows = [
    {
      'id': 'menu-1',
      'name': 'ข้าวกะเพรา',
      'price': 75,
      'category': 'อาหาร',
      'description': '',
      'is_available': true,
    },
  ];
  List<Json> orderRows = [
    {
      'id': 'order-1',
      'order_number': 'TEST-1',
      'recipient_name': 'ลูกค้าทดสอบ',
      'recipient_phone': '0811111111',
      'shipping_address': 'ที่อยู่ทดสอบ',
      'status': 'pending_acceptance',
      'payment_status': 'paid',
      'total': 75,
      'subtotal': 75,
      'delivery_fee': 0,
      'created_at': '2026-10-21T03:00:00Z',
      'food_order_items': [
        {'item_name': 'ข้าวกะเพรา', 'quantity': 1},
      ],
    },
    {
      'id': 'order-2',
      'order_number': 'TEST-2',
      'recipient_name': 'ยังไม่ชำระ',
      'recipient_phone': '0822222222',
      'shipping_address': 'ที่อยู่ทดสอบ',
      'status': 'pending_acceptance',
      'payment_status': 'pending',
      'total': 80,
      'subtotal': 80,
      'delivery_fee': 0,
      'created_at': '2026-10-21T04:00:00Z',
      'food_order_items': [],
    },
  ];
  void read() {
    if (failReads) throw Exception('offline');
  }

  void write() {
    writes++;
    if (failWrites) {
      throw const MerchantException('บัญชีนี้ไม่มีสิทธิ์ดำเนินการ');
    }
  }

  @override
  Future<List<Json>> stores() async {
    read();
    return access ? storeRows.map(Json.from).toList() : [];
  }

  @override
  Future<bool> hasRole(String id, List<String> roles) async => manager;
  @override
  Future<List<Json>> menu(String id) async {
    read();
    return menuRows.map(Json.from).toList();
  }

  @override
  Future<List<Json>> orders(String id, String status, int offset) async {
    read();
    orderReads++;
    return orderRows
        .where((o) => o['status'] == status)
        .skip(offset)
        .take(50)
        .map(Json.from)
        .toList();
  }

  @override
  Future<Json> report(String id) async => {
    'today_sales': 174,
    'today_orders': 2,
    'month_sales': 500,
    'total_orders': 5,
    'best': [],
  };
  @override
  Future<Json> campaigns(String id) async => {
    'can_manage': manager,
    'campaigns': [],
  };
  @override
  Future<void> saveMenu(String storeId, Json values, {String? id}) async {
    write();
    if (id == null) {
      menuRows.add({'id': 'new-menu', ...values, 'is_available': true});
    } else {
      menuRows.firstWhere((m) => m['id'] == id).addAll(values);
    }
  }

  @override
  Future<void> saveStore(String id, Json values) async {
    write();
    storeRows.firstWhere((s) => s['id'] == id).addAll(values);
  }

  @override
  Future<void> transition(
    String storeId,
    String id,
    String status, {
    String? note,
  }) async {
    write();
    orderRows.firstWhere((o) => o['id'] == id)['status'] = status;
  }

  @override
  Future<void> createCampaign(String id, String name, double discount) async {
    write();
  }

  @override
  Future<void> setCampaignActive(
    String id,
    String campaign,
    bool active,
  ) async {
    write();
  }

  @override
  Future<void> payment(
    String storeId,
    String orderId,
    String status, {
    String? note,
  }) async {
    write();
    orderRows.firstWhere((o) => o['id'] == orderId)['payment_status'] = status;
  }

  @override
  Future<Json?> pickDeliveryPhoto(String storeId, String orderId) async => {
    'path': 'delivery/$orderId/proof.jpg',
    'previewUrl': 'https://example.invalid/proof.jpg',
  };
  @override
  Future<void> completeDelivery(
    String storeId,
    String orderId,
    String method,
    String imagePath, {
    String? locationNote,
  }) async {
    write();
    orderRows.firstWhere((o) => o['id'] == orderId)['status'] = 'delivered';
  }

  @override
  Future<String?> signedUrl(
    String storeId,
    String orderId,
    String kind,
  ) async => null;
  @override
  Future<void> subscribe(String storeId) async {}
  @override
  Future<Json> pushStatus() async => {'enabled': false, 'available': true};
  @override
  Future<Json> pushEnable() async => {'ok': true};
  @override
  Future<Json> pushDisable() async => {'ok': true};
  @override
  Future<void> signOut() async {}
}
