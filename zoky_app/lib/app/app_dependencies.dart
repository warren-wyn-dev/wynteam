import 'package:flutter/widgets.dart';

import '../features/catalog/data/store_repository.dart';
import 'app_config.dart';

/// Hands app-wide dependencies (config, repositories) down the tree without
/// a state-management package (architecture doc section 5). Screens read
/// them once with [AppDependencies.of] and pass them on by constructor.
class AppDependencies extends InheritedWidget {
  const AppDependencies({
    super.key,
    required this.config,
    required this.storeRepository,
    required super.child,
  });

  final AppConfig config;
  final StoreRepository storeRepository;

  static AppDependencies of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<AppDependencies>();
    assert(result != null, 'No AppDependencies above this context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppDependencies oldWidget) =>
      config != oldWidget.config ||
      storeRepository != oldWidget.storeRepository;
}
