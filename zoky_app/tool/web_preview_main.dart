// Design-review preview entrypoint (not shipped in the store app).
// Same widgets as ZokyApp with demo data, plus a simulated iPhone safe area
// and status bar, because a browser reports no view padding. Build with:
//   flutter build web --release --no-web-resources-cdn -t tool/web_preview_main.dart
// Query params: ?platform=android to preview Android-adaptive widgets,
// ?top=/&bottom= to change the simulated insets.
import 'dart:async' show Timer;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zoky_app/app/app_config.dart';
import 'package:zoky_app/app/app_dependencies.dart';
import 'package:zoky_app/core/design/zoky_theme.dart';
import 'package:zoky_app/features/address/data/demo_address_repository.dart';
import 'package:zoky_app/features/address/delivery_address_controller.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/deals/data/demo_promotion_repository.dart';
import 'package:zoky_app/features/home/data/demo_home_content_repository.dart';
import 'package:zoky_app/features/food/collected_promos_controller.dart';
import 'package:zoky_app/features/fulfillment/fulfillment_mode_controller.dart';
import 'package:zoky_app/features/shell/zoky_shell.dart';

void main() {
  final uri = Uri.base;
  final top =
      double.tryParse(uri.queryParameters['top'] ?? '') ??
      59; // iPhone 15 Pro Max status bar + Dynamic Island
  final bottom = double.tryParse(uri.queryParameters['bottom'] ?? '') ?? 34;
  final android = uri.queryParameters['platform'] == 'android';
  runApp(
    AppDependencies(
      config: AppConfig.demo,
      storeRepository: DemoStoreRepository(),
      promotionRepository: const DemoPromotionRepository(),
      homeContentRepository: const DemoHomeContentRepository(),
      deliveryAddresses: DeliveryAddressController(
        const DemoAddressRepository(),
      ),
      fulfillmentMode: FulfillmentModeController(),
      collectedPromos: CollectedPromosController(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // Mouse drags page carousels/rows like a finger in the preview.
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
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
                  child: const IgnorePointer(child: _FakeStatusBar()),
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

/// Simulated status bar whose text/icons follow the app's current
/// [SystemUiOverlayStyle] (the AnnotatedRegion under the status bar), like
/// iOS/Android do: dark content over light headers, white over pink.
class _FakeStatusBar extends StatefulWidget {
  const _FakeStatusBar();

  @override
  State<_FakeStatusBar> createState() => _FakeStatusBarState();
}

class _FakeStatusBarState extends State<_FakeStatusBar> {
  bool _dark = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      // SystemChrome applies the frame's style in a microtask; read it
      // after that.
      Timer.run(() {
        // Preview harness only (not shipped): read what the framework
        // last sent to the platform.
        // ignore: invalid_use_of_visible_for_testing_member
        final style = SystemChrome.latestStyle;
        final dark =
            style?.statusBarBrightness == Brightness.light ||
            style?.statusBarIconBrightness == Brightness.dark;
        if (_active && mounted && dark != _dark) setState(() => _dark = dark);
      });
    });
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _dark ? const Color(0xFF16161A) : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Text(
            '14:19',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Anuphan',
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          Icon(Icons.signal_cellular_alt, size: 17, color: color),
          const SizedBox(width: 4),
          Icon(Icons.wifi, size: 17, color: color),
          const SizedBox(width: 4),
          Icon(Icons.battery_full, size: 18, color: color),
        ],
      ),
    );
  }
}
