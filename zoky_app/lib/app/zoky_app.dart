import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/design/zoky_theme.dart';
import '../core/l10n/zoky_strings.dart';
import '../features/catalog/data/store_repository.dart';
import '../features/shell/zoky_shell.dart';
import 'app_config.dart';
import 'app_dependencies.dart';

/// Root widget: ZOKY theme (light only for v1), Thai locale, 4-tab shell.
class ZokyApp extends StatelessWidget {
  const ZokyApp({
    super.key,
    required this.config,
    required this.storeRepository,
  });

  final AppConfig config;
  final StoreRepository storeRepository;

  @override
  Widget build(BuildContext context) {
    return AppDependencies(
      config: config,
      storeRepository: storeRepository,
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
        home: const ZokyShell(),
      ),
    );
  }
}
