import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/app_config.dart';
import 'app/zoky_app.dart';
import 'features/catalog/data/demo_store_repository.dart';
import 'features/deals/data/demo_promotion_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // SIL OFL 1.1 requires the license to travel with the bundled font; it
  // shows up in Flutter's license page (showLicensePage).
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/anuphan/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Anuphan'], text);
  });

  // Portrait only (Founder, 2026-10-17; closes ZOKY-124), matching the
  // native Info.plist / AndroidManifest locks.
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);

  final config = AppConfig.fromEnvironment();

  // ZOKY-104 scaffold: only demo repositories exist. ZOKY-105 adds
  // Supabase.initialize(url: config.supabaseUrl, publishableKey:
  // config.supabaseAnonKey) and Supabase*Repository, chosen when
  // !config.isDemoMode.
  if (!config.isDemoMode) {
    debugPrint(
      'ZOKY: Supabase repositories are not wired yet (ZOKY-105); '
      'running with demo data.',
    );
  }

  runApp(
    ZokyApp(
      config: config,
      storeRepository: DemoStoreRepository(
        latency: const Duration(milliseconds: 600),
      ),
      promotionRepository: const DemoPromotionRepository(
        latency: Duration(milliseconds: 600),
      ),
    ),
  );
}
