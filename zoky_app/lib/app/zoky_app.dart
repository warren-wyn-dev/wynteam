import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/design/zoky_theme.dart';
import '../core/l10n/zoky_strings.dart';
import '../features/catalog/data/store_repository.dart';
import '../features/deals/data/promotion_repository.dart';
import '../features/shell/zoky_shell.dart';
import 'app_config.dart';
import 'app_dependencies.dart';

/// Root widget: ZOKY theme (light only for v1), Thai locale, 4-tab shell.
class ZokyApp extends StatelessWidget {
  const ZokyApp({
    super.key,
    required this.config,
    required this.storeRepository,
    required this.promotionRepository,
  });

  final AppConfig config;
  final StoreRepository storeRepository;
  final PromotionRepository promotionRepository;

  @override
  Widget build(BuildContext context) {
    return AppDependencies(
      config: config,
      storeRepository: storeRepository,
      promotionRepository: promotionRepository,
      child: MaterialApp(
        title: ZokyStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: buildZokyTheme(),
        themeMode: ThemeMode.light,
        locale: const Locale('th'),
        supportedLocales: const [Locale('th')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        // Default status bar: dark content for the white screens. The pink
        // Home header overrides it with its own light region while it is on
        // screen (statusBarBrightness is the iOS field).
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: child!,
        ),
        home: const ZokyShell(),
      ),
    );
  }
}
