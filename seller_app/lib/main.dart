import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'features/auth/presentation/seller_auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  runApp(const ZokySellerApp());
}

class ZokySellerApp extends StatelessWidget {
  const ZokySellerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZOKY Sellers by WYN',
      debugShowCheckedModeBanner: false,
      // Same seed/Material 3 setup as app/lib/main.dart (WYN Social) --
      // Blue + White + Soft Gray, duplicated rather than shared since
      // this is a separate Flutter binary. See
      // .wyn/company/DECISIONS.md, 2026-08-15.
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2D6CDF),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2D6CDF),
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const SellerAuthGate(),
    );
  }
}
