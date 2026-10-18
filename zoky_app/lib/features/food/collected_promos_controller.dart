import 'package:flutter/foundation.dart';

/// Store promos the customer tapped "เก็บโค้ด" on (web parity: promoCard
/// toggleCollected, saved per user under the localStorage key
/// `wynos-food-collected-promos-v1:<userId>`).
///
/// In memory only for now (handed down by AppDependencies, so it survives
/// leaving the food page but not an app restart). TODO(ZOKY-105): persist
/// per signed-in user once accounts and local storage are wired.
class CollectedPromosController extends ChangeNotifier {
  final Set<String> _storeIds = {};

  bool isCollected(String storeId) => _storeIds.contains(storeId);

  /// Collects the store's promo, or un-collects it when already collected
  /// (same toggle as the web).
  void toggle(String storeId) {
    if (!_storeIds.remove(storeId)) _storeIds.add(storeId);
    notifyListeners();
  }
}
