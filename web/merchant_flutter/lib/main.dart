import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/bridge_transport.dart';
import 'data/merchant_repository.dart';
import 'screens/merchant_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runWidget(const MerchantViews());
}

/// Each React mount gets its own Flutter view; removing it disposes customer
/// data, controllers and listeners before another account can mount a view.
class MerchantViews extends StatefulWidget {
  const MerchantViews({super.key});
  @override
  State<MerchantViews> createState() => _MerchantViewsState();
}

class _MerchantViewsState extends State<MerchantViews>
    with WidgetsBindingObserver {
  late final SemanticsHandle semantics;
  @override
  void initState() {
    super.initState();
    semantics = SemanticsBinding.instance.ensureSemantics();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    semantics.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() => setState(() {});
  @override
  Widget build(BuildContext context) => ViewCollection(
    views: [
      for (final view in WidgetsBinding.instance.platformDispatcher.views)
        View(
          key: ValueKey(view.viewId),
          view: view,
          child: const MerchantView(),
        ),
    ],
  );
}

class MerchantView extends StatefulWidget {
  const MerchantView({super.key});
  @override
  State<MerchantView> createState() => _MerchantViewState();
}

class _MerchantViewState extends State<MerchantView> {
  late final transport = createBridgeTransport();
  late final repository = BridgeMerchantRepository(transport);
  @override
  void dispose() {
    transport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ZokyApp(
    home: MerchantHome(repository: repository, onSignOut: repository.signOut),
  );
}

class ZokyApp extends StatelessWidget {
  const ZokyApp({super.key, required this.home});
  final Widget home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Zoky Merchant',
    locale: const Locale('th'),
    supportedLocales: const [Locale('th'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF087F5B),
        primary: const Color(0xFF087F5B),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE5EBE7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F7F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: home,
  );
}
