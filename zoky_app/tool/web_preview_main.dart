// Design-review preview entrypoint (not shipped in the store app).
// Same widgets as ZokyApp with demo data, plus a simulated iPhone safe area
// and status bar, because a browser reports no view padding. Build with:
//   flutter build web --release --no-web-resources-cdn -t tool/web_preview_main.dart
// Query params: ?platform=android to preview Android-adaptive widgets,
// ?top=/&bottom= to change the simulated insets.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zoky_app/app/app_config.dart';
import 'package:zoky_app/app/app_dependencies.dart';
import 'package:zoky_app/core/design/zoky_theme.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/shell/zoky_shell.dart';

void main() {
  final uri = Uri.base;
  final top = double.tryParse(uri.queryParameters['top'] ?? '') ?? 47;
  final bottom = double.tryParse(uri.queryParameters['bottom'] ?? '') ?? 34;
  final android = uri.queryParameters['platform'] == 'android';
  runApp(
    AppDependencies(
      config: AppConfig.demo,
      storeRepository: DemoStoreRepository(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZokyTheme().copyWith(
          platform: android ? TargetPlatform.android : TargetPlatform.iOS,
        ),
        locale: const Locale('th'),
        supportedLocales: const [Locale('th')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final pad = EdgeInsets.only(top: top, bottom: bottom);
          return MediaQuery(
            data: mq.copyWith(padding: pad, viewPadding: pad),
            child: Stack(
              children: [
                child!,
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: top,
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        children: [
                          Text(
                            '14:19',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Anuphan',
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.signal_cellular_alt,
                            size: 17,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.wifi, size: 17, color: Colors.white),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.battery_full,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        home: const ZokyShell(),
      ),
    ),
  );
}
