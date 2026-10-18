import 'package:flutter/foundation.dart';

/// How the customer gets the order.
enum FulfillmentMode { delivery, pickup }

/// App-wide "จัดส่ง | รับเองที่ร้าน" choice (Founder decision "ค",
/// 2026-10-18: pickup opens as a new feature). A plain [ChangeNotifier]
/// handed down by AppDependencies, like [DeliveryAddressController], so the
/// cart and checkout can read it later.
///
/// UI slice only: the backend, merchant and payment side of pickup is a
/// separate planned task. Lives in memory; starts on [FulfillmentMode.delivery].
class FulfillmentModeController extends ChangeNotifier {
  FulfillmentModeController({
    FulfillmentMode initial = FulfillmentMode.delivery,
  }) : _mode = initial;

  FulfillmentMode _mode;

  FulfillmentMode get mode => _mode;
  bool get isPickup => _mode == FulfillmentMode.pickup;

  void select(FulfillmentMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }
}
