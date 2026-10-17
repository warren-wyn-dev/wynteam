import '../../deals/domain/deal_models.dart';
import '../domain/catalog_models.dart';
import 'store_repository.dart';

/// Synthetic Thai sample catalog for demo mode (iPad web preview, widget
/// tests). Every store, menu and price here is made up -- no real store or
/// customer data. Never used when real Supabase config is supplied.
///
/// Every store is flagged [ZokyStoreSummary.isDemo] and its name carries
/// "(ร้านตัวอย่าง)"; ratings and delivery times are sample values too.
class DemoStoreRepository implements StoreRepository {
  DemoStoreRepository({this.latency = Duration.zero});

  /// Artificial delay so the preview shows loading skeletons.
  final Duration latency;

  static const List<ZokyStoreSummary> stores = [
    ZokyStoreSummary(
      id: 'demo-store-1',
      name: 'ข้าวมันไก่ป้าแดง (ร้านตัวอย่าง)',
      isDemo: true,
      isOpen: true,
      deliveryFee: 15,
      etaMinMinutes: 20,
      etaMaxMinutes: 30,
      isAd: true,
      ratingAverage: 4.8,
      ratingCount: 1250,
      distanceKm: 1.2,
      categories: ['ข้าวมันไก่', 'อาหารจานเดียว'],
      minimumOrder: 50,
    ),
    ZokyStoreSummary(
      id: 'demo-store-2',
      name: 'ส้มตำแซ่บนัว (ร้านตัวอย่าง)',
      coverArt: ZokyDealArt.somTam,
      isDemo: true,
      isOpen: true,
      deliveryFee: 0,
      etaMinMinutes: 25,
      etaMaxMinutes: 35,
      promoLabel: 'ส่งฟรี',
      ratingAverage: 4.6,
      ratingCount: 320,
      distanceKm: 2.4,
      categories: ['อีสาน', 'ส้มตำ'],
    ),
    ZokyStoreSummary(
      id: 'demo-store-3',
      name: 'ก๋วยเตี๋ยวเรือหน้ามอ (ร้านตัวอย่าง)',
      isDemo: true,
      isOpen: false,
      deliveryFee: 20,
      etaMinMinutes: 30,
      etaMaxMinutes: 40,
      ratingAverage: 4.3,
      ratingCount: 88,
      distanceKm: 3.8,
      categories: ['ก๋วยเตี๋ยว'],
    ),
    ZokyStoreSummary(
      id: 'demo-store-4',
      name: 'ชานมไข่มุกหวานใจ (ร้านตัวอย่าง)',
      coverArt: ZokyDealArt.bubbleTea,
      isDemo: true,
      isOpen: true,
      deliveryFee: 10,
      etaMinMinutes: 15,
      etaMaxMinutes: 25,
      promoLabel: 'ลด 20%',
      distanceKm: 0.8,
      categories: ['เครื่องดื่ม', 'ของหวาน'],
    ),
    ZokyStoreSummary(
      id: 'demo-store-5',
      name: 'ข้าวผัดกะเพราเจ้าเก่า (ร้านตัวอย่าง)',
      isDemo: true,
      isOpen: true,
      deliveryFee: 12,
      etaMinMinutes: 20,
      etaMaxMinutes: 30,
      ratingAverage: 4.9,
      ratingCount: 2045,
      distanceKm: 1.9,
      categories: ['อาหารตามสั่ง'],
      minimumOrder: 40,
    ),
    ZokyStoreSummary(
      id: 'demo-store-6',
      name: 'หมูกระทะยกถาด (ร้านตัวอย่าง)',
      isDemo: true,
      isOpen: true,
      deliveryFee: 25,
      etaMinMinutes: 35,
      etaMaxMinutes: 50,
      promoLabel: 'ลด ฿30',
      ratingAverage: 4.5,
      ratingCount: 140,
      distanceKm: 4.6,
      categories: ['ปิ้งย่าง'],
      minimumOrder: 199,
    ),
    // Stores of the Phase 3 sample deals, featured on Home Phase 4.
    ZokyStoreSummary(
      id: 'demo-store-7',
      name: 'ราเมงซอยเจ็ด (ร้านตัวอย่าง)',
      coverArt: ZokyDealArt.noodleBowl,
      isDemo: true,
      isOpen: true,
      deliveryFee: 15,
      etaMinMinutes: 30,
      etaMaxMinutes: 45,
      ratingAverage: 4.8,
      ratingCount: 512,
      distanceKm: 2.1,
      categories: ['ราเมง', 'ญี่ปุ่น'],
    ),
    ZokyStoreSummary(
      id: 'demo-store-8',
      name: 'เบอร์เกอร์บ้านสวน (ร้านตัวอย่าง)',
      coverArt: ZokyDealArt.burger,
      isDemo: true,
      isOpen: true,
      deliveryFee: 20,
      etaMinMinutes: 25,
      etaMaxMinutes: 40,
      ratingAverage: 4.6,
      ratingCount: 274,
      distanceKm: 2.9,
      categories: ['เบอร์เกอร์', 'ฟาสต์ฟู้ด'],
    ),
    // No prep time set: no delivery estimate is shown.
    ZokyStoreSummary(
      id: 'demo-store-9',
      name: 'ไก่ทอดกรอบนอก (ร้านตัวอย่าง)',
      coverArt: ZokyDealArt.friedChicken,
      isDemo: true,
      isOpen: true,
      deliveryFee: 15,
      ratingAverage: 4.4,
      ratingCount: 61,
      distanceKm: 1.6,
      categories: ['ไก่ทอด'],
    ),
  ];

  /// Sample featured placements in priority order (web:
  /// food_active_featured_stores). Includes a store without reviews
  /// (demo-store-4) and one without a delivery estimate (demo-store-9).
  static const List<String> featuredStoreIds = [
    'demo-store-7',
    'demo-store-8',
    'demo-store-2',
    'demo-store-4',
    'demo-store-9',
  ];

  static const Map<String, List<ZokyMenuItem>> menus = {
    'demo-store-1': [
      ZokyMenuItem(
        id: 'demo-item-1-1',
        storeId: 'demo-store-1',
        category: 'ข้าวมันไก่',
        name: 'ข้าวมันไก่ต้ม',
        description: 'ไก่ต้มนุ่ม ข้าวมันหอม น้ำจิ้มเต้าเจี้ยวสูตรร้าน',
        price: 50,
      ),
      ZokyMenuItem(
        id: 'demo-item-1-2',
        storeId: 'demo-store-1',
        category: 'ข้าวมันไก่',
        name: 'ข้าวมันไก่ทอด',
        description: 'ไก่ทอดกรอบ เสิร์ฟพร้อมน้ำจิ้มหวาน',
        price: 55,
        remainingStock: 3,
      ),
      ZokyMenuItem(
        id: 'demo-item-1-3',
        storeId: 'demo-store-1',
        category: 'ข้าวมันไก่',
        name: 'ข้าวมันไก่รวม (ต้ม + ทอด)',
        price: 65,
      ),
      ZokyMenuItem(
        id: 'demo-item-1-4',
        storeId: 'demo-store-1',
        category: 'เครื่องเคียง',
        name: 'ซุปฟัก',
        price: 20,
        isAvailable: false,
      ),
    ],
    'demo-store-2': [
      ZokyMenuItem(
        id: 'demo-item-2-1',
        storeId: 'demo-store-2',
        category: 'ส้มตำ',
        name: 'ตำไทยไข่เค็ม',
        description: 'เปรี้ยว หวาน เผ็ดกำลังดี',
        price: 60,
      ),
      ZokyMenuItem(
        id: 'demo-item-2-2',
        storeId: 'demo-store-2',
        category: 'ส้มตำ',
        name: 'ตำปูปลาร้า',
        price: 55,
      ),
      ZokyMenuItem(
        id: 'demo-item-2-3',
        storeId: 'demo-store-2',
        category: 'ปิ้งย่าง',
        name: 'ไก่ย่างครึ่งตัว',
        price: 120,
      ),
    ],
  };

  @override
  Future<List<ZokyStoreSummary>> fetchDirectory({String query = ''}) async {
    await Future<void>.delayed(latency);
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return stores;
    return stores
        .where(
          (store) =>
              store.name.toLowerCase().contains(needle) ||
              store.categories.any((c) => c.toLowerCase().contains(needle)),
        )
        .toList();
  }

  @override
  Future<List<ZokyStoreSummary>> fetchRecommended() async {
    await Future<void>.delayed(latency);
    return [
      for (final id in featuredStoreIds)
        ...stores.where((store) => store.id == id),
    ];
  }

  @override
  Future<List<ZokyMenuItem>> fetchMenu(String storeId) async {
    await Future<void>.delayed(latency);
    return menus[storeId] ??
        [
          ZokyMenuItem(
            id: '$storeId-item-1',
            storeId: storeId,
            category: 'เมนูแนะนำ',
            name: 'เมนูตัวอย่าง',
            description: 'ข้อมูลตัวอย่างสำหรับโหมดสาธิต',
            price: 45,
          ),
        ];
  }
}
