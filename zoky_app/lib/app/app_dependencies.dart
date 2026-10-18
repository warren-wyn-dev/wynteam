import 'package:flutter/widgets.dart';

import '../features/address/delivery_address_controller.dart';
import '../features/catalog/data/store_repository.dart';
import '../features/deals/data/promotion_repository.dart';
import '../features/home/data/home_content_repository.dart';
import 'app_config.dart';

/// Hands app-wide dependencies (config, repositories) down the tree without
/// a state-management package (architecture doc section 5). Screens read
/// them once with [AppDependencies.of] and pass them on by constructor.
class AppDependencies extends InheritedWidget {
  const AppDependencies({
    super.key,
    required this.config,
    required this.storeRepository,
    required this.promotionRepository,
    required this.homeContentRepository,
    required this.deliveryAddresses,
    required super.child,
  });

  final AppConfig config;
  final StoreRepository storeRepository;
  final PromotionRepository promotionRepository;
  final HomeContentRepository homeContentRepository;

  /// Saved addresses + the selected "จัดส่งที่" (listen to it for changes).
  final DeliveryAddressController deliveryAddresses;

  static AppDependencies of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<AppDependencies>();
    assert(result != null, 'No AppDependencies above this context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppDependencies oldWidget) =>
      config != oldWidget.config ||
      storeRepository != oldWidget.storeRepository ||
      promotionRepository != oldWidget.promotionRepository ||
      homeContentRepository != oldWidget.homeContentRepository ||
      deliveryAddresses != oldWidget.deliveryAddresses;
}
