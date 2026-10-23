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
      scaffoldBackgroundColor: const Color(0xFFF6F6F8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFD61256),
        primary: const Color(0xFFD61256),
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: const Color(0xFF16161A),
        primaryContainer: const Color(0xFFFFEFF5),
        onPrimaryContainer: const Color(0xFFAF1341),
        outline: const Color(0xFF8A8A94),
        outlineVariant: const Color(0xFFEBEBEF),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEBEBEF)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFEFF5),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? const Color(0xFFD61256)
                : const Color(0xFF6B6B76),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFFD61256)
                : const Color(0xFF6B6B76),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: const Color(0xFFFFEFF5),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFEBEBEF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFEBEBEF)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF6F6F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: home,
  );
}
