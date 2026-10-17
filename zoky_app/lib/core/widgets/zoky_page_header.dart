import 'package:flutter/material.dart';

import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';

/// Large left-aligned title used at the top of each main tab (web
/// `FoodPageHeader`; shared on every platform per design 11.1).
class ZokyPageHeader extends StatelessWidget {
  const ZokyPageHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZokySpacing.gutter,
        ZokySpacing.s6,
        ZokySpacing.gutter,
        ZokySpacing.s4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: ZokyTextStyles.titleLg),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
