import '../domain/address_models.dart';
import 'address_repository.dart';

/// Made-up addresses for demo mode. No real person, place or phone: every
/// label says "(ตัวอย่าง)" and the text is generic sample copy.
class DemoAddressRepository implements AddressRepository {
  const DemoAddressRepository({this.latency = Duration.zero});

  /// Artificial delay so the preview shows the loading state.
  final Duration latency;

  static const List<ZokyDeliveryAddress> addresses = [
    ZokyDeliveryAddress(
      id: 'demo-address-1',
      label: 'บ้าน (ตัวอย่าง)',
      address: '99/9 ถนนตัวอย่าง แขวงตัวอย่าง เขตตัวอย่าง กรุงเทพฯ 10000',
      latitude: 13.7563,
      longitude: 100.5018,
      deliveryNote: 'วางไว้หน้าประตู (ตัวอย่าง)',
      isDefault: true,
      isDemo: true,
    ),
    ZokyDeliveryAddress(
      id: 'demo-address-2',
      label: 'ที่ทำงาน (ตัวอย่าง)',
      address: 'อาคารตัวอย่าง ชั้น 9 ถนนตัวอย่าง เขตตัวอย่าง กรุงเทพฯ 10000',
      latitude: 13.7466,
      longitude: 100.5393,
      isDemo: true,
    ),
    ZokyDeliveryAddress(
      id: 'demo-address-3',
      label: 'คอนโด (ตัวอย่าง)',
      address: '1/1 ซอยตัวอย่าง ถนนตัวอย่าง เขตตัวอย่าง กรุงเทพฯ 10000',
      isDemo: true,
    ),
  ];

  @override
  Future<List<ZokyDeliveryAddress>> fetchSavedAddresses() async {
    await Future<void>.delayed(latency);
    return addresses;
  }
}
