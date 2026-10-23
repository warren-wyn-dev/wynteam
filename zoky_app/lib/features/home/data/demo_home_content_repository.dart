import '../../deals/domain/deal_models.dart';
import '../domain/home_content_models.dart';
import 'home_content_repository.dart';

/// Made-up Home content for demo mode (web preview, widget tests). Every
/// banner is [ZokyHomeBanner.isDemo] and carries "(ตัวอย่าง)": none is a
/// real promotion. Targets point at the demo stores/deals only.
class DemoHomeContentRepository implements HomeContentRepository {
  const DemoHomeContentRepository({
    this.latency = Duration.zero,
    this.clock = DateTime.now,
  });

  /// Artificial delay so the preview shows loading states.
  final Duration latency;

  /// Time source for the active-window rule (tests).
  final DateTime Function() clock;

  /// The RPC returns at most 8 banners.
  static const int maxBanners = 8;

  static final List<ZokyHomeBanner> banners = [
    const ZokyHomeBanner(
      id: 'demo-banner-1',
      title: 'ส่งฟรี ส้มตำแซ่บนัว (ตัวอย่าง)',
      subtitle: 'แตะเพื่อดูร้านตัวอย่าง',
      destinationStoreId: 'demo-store-2',
      art: ZokyDealArt.somTam,
      sortOrder: 10,
      isDemo: true,
    ),
    const ZokyHomeBanner(
      id: 'demo-banner-2',
      title: 'ลด 50% ชานมไข่มุก (ตัวอย่าง)',
      subtitle: 'ดีลตัวอย่าง ยังไม่ใช่โปรโมชันจริง',
      dealId: 'demo-deal-1',
      art: ZokyDealArt.bubbleTea,
      sortOrder: 20,
      isDemo: true,
    ),
    const ZokyHomeBanner(
      id: 'demo-banner-3',
      title: 'ราเมงซุปเข้มข้น (ตัวอย่าง)',
      subtitle: 'แบนเนอร์ตัวอย่างที่ไม่มีปลายทาง',
      art: ZokyDealArt.noodleBowl,
      sortOrder: 30,
      isDemo: true,
    ),
    // Outside its window: never shown (same rule as the RPC).
    ZokyHomeBanner(
      id: 'demo-banner-expired',
      title: 'แบนเนอร์หมดอายุ (ตัวอย่าง)',
      art: ZokyDealArt.burger,
      sortOrder: 0,
      endsAt: DateTime.utc(2020),
      isDemo: true,
    ),
  ];

  static const List<ZokyFoodCategory> categories = [
    ZokyFoodCategory(
      id: 'made-to-order',
      label: 'ตามสั่ง',
      art: ZokyDealArt.kaprao,
      terms: ['ตามสั่ง', 'กะเพรา', 'ข้าวผัด', 'ข้าวมันไก่', 'จานเดียว'],
    ),
    ZokyFoodCategory(
      id: 'noodles',
      label: 'ก๋วยเตี๋ยว',
      art: ZokyDealArt.noodleBowl,
      terms: ['ก๋วยเตี๋ยว', 'ราเมง', 'บะหมี่'],
    ),
    ZokyFoodCategory(
      id: 'isan',
      label: 'อีสาน',
      art: ZokyDealArt.somTam,
      terms: ['อีสาน', 'ส้มตำ'],
    ),
    ZokyFoodCategory(
      id: 'drinks',
      label: 'เครื่องดื่ม',
      art: ZokyDealArt.bubbleTea,
      terms: ['เครื่องดื่ม', 'ชานม', 'กาแฟ'],
    ),
    ZokyFoodCategory(
      id: 'fast-food',
      label: 'ฟาสต์ฟู้ด',
      art: ZokyDealArt.burger,
      terms: ['ฟาสต์ฟู้ด', 'เบอร์เกอร์', 'พิซซ่า'],
    ),
    ZokyFoodCategory(
      id: 'fried-chicken',
      label: 'ไก่ทอด',
      art: ZokyDealArt.friedChicken,
      terms: ['ไก่ทอด'],
    ),
    ZokyFoodCategory(
      id: 'desserts',
      label: 'ของหวาน',
      art: ZokyDealArt.dessert,
      terms: ['ของหวาน', 'ขนม', 'ไอศกรีม', 'เบเกอรี่'],
    ),
  ];

  @override
  Future<List<ZokyHomeBanner>> fetchActiveBanners() async {
    await Future<void>.delayed(latency);
    final now = clock();
    final active = banners.where((b) => b.isActiveAt(now)).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return active.take(maxBanners).toList();
  }

  @override
  Future<List<ZokyFoodCategory>> fetchFoodCategories() async {
    await Future<void>.delayed(latency);
    return categories;
  }
}
