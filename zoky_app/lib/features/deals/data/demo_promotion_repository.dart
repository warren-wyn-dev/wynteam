import '../domain/deal_models.dart';
import 'promotion_repository.dart';

/// Made-up sample deals for demo mode (web preview, widget tests). None of
/// these is a real promotion or a real discount: every deal has
/// [ZokyDeal.isDemo] set, the stores are "(ร้านตัวอย่าง)" and the UI labels
/// each card "ตัวอย่าง". Never used when a real backend is configured.
class DemoPromotionRepository implements PromotionRepository {
  const DemoPromotionRepository({this.latency = Duration.zero});

  /// Artificial delay so the preview shows the loading skeleton.
  final Duration latency;

  static const List<ZokyDeal> deals = [
    ZokyDeal(
      id: 'demo-deal-1',
      name: 'ลด 50% ชานมไข่มุก (ตัวอย่าง)',
      type: ZokyDealType.percentage,
      value: 50,
      description: 'ชานมไข่มุก',
      art: ZokyDealArt.bubbleTea,
      storeId: 'demo-store-4',
      storeName: 'ชานมไข่มุกหวานใจ (ร้านตัวอย่าง)',
      isDemo: true,
    ),
    ZokyDeal(
      id: 'demo-deal-2',
      name: '1 แถม 1',
      type: ZokyDealType.other,
      description: 'ไก่ทอดสุดฮิต',
      art: ZokyDealArt.friedChicken,
      storeName: 'ไก่ทอดกรอบนอก (ร้านตัวอย่าง)',
      isDemo: true,
    ),
    ZokyDeal(
      id: 'demo-deal-3',
      name: 'ลด ฿30 เบอร์เกอร์ (ตัวอย่าง)',
      type: ZokyDealType.fixed,
      value: 30,
      minSubtotal: 199,
      description: 'เบอร์เกอร์ชีส',
      art: ZokyDealArt.burger,
      storeName: 'เบอร์เกอร์บ้านสวน (ร้านตัวอย่าง)',
      isDemo: true,
    ),
    ZokyDeal(
      id: 'demo-deal-4',
      name: 'ส่งฟรี ราเมง (ตัวอย่าง)',
      type: ZokyDealType.freeDelivery,
      description: 'ราเมงซุปเข้มข้น',
      art: ZokyDealArt.noodleBowl,
      storeName: 'ราเมงซอยเจ็ด (ร้านตัวอย่าง)',
      isDemo: true,
    ),
  ];

  @override
  Future<List<ZokyDeal>> fetchTodayDeals() async {
    await Future<void>.delayed(latency);
    return deals;
  }
}
