import 'package:flutter/material.dart';

import 'seller_strings.dart';

/// The single reusable placeholder for every SellerHomeShell tab that
/// isn't built yet. See .wyn/docs/design/seller-001-foundation.md,
/// Screen: SellerComingSoonScreen.
class SellerComingSoonScreen extends StatelessWidget {
  const SellerComingSoonScreen({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: const Center(child: Text(zokyComingSoonMessage)),
    );
  }
}
