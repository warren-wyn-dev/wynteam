// Scoped to app/ only -- NOT a mirror of anything in seller_app/, and not
// mirrored there. This is the missing half of
// .wyn/docs/design/ds-001-color-system.md, Section 3.4/4: that spec names
// app/'s own files (product_grid_tile.dart, product_detail_screen,
// cart, order, store_screen, OrderStatusBadge, root_shell.dart) as the
// places `colorScheme.tertiary` should resolve to ZOKY Orange, but
// DS-001b only ever built an Orange ColorScheme for seller_app/'s
// `ZokyTheme` -- app/'s own `WynTheme` keeps `tertiary: cyan500` for its
// (accepted-risk) bare-link-text use everywhere else in WYN Social, so
// every ZOKY Marketplace screen inside app/ was silently reading Cyan for
// "price" instead of Orange. Found during DS-007's audit (2026-08-16).
//
// Unlike seller_app/'s ZokyTheme (its whole-app theme, since that app IS
// the commerce layer), this only swaps the tertiary family -- primary
// stays Cyan -- and is applied per-screen (see usage below), not
// app-wide, because plain `Navigator.push(MaterialPageRoute(...))` (used
// by every screen transition in this codebase) does not inherit an
// ancestor `Theme` override placed only around the ZOKY tab's entry
// point: a pushed route's subtree sits as a sibling in the Navigator's
// Overlay, not as a descendant of whatever locally wrapped the widget
// that pushed it. Each ZOKY-owned screen therefore wraps its own
// Scaffold in [ZokyAccentTheme] directly.
import 'package:flutter/material.dart';

import 'wyn_colors.dart';

/// Wraps [child] in a `Theme` override that swaps `ColorScheme.tertiary`
/// (and its `onTertiary`/`tertiaryContainer`/`onTertiaryContainer`
/// siblings) from WYN Social's Cyan to ZOKY's Orange -- values copied
/// verbatim from `seller_app/lib/core/design/wyn_zoky_theme.dart`'s
/// `_lightScheme`/`_darkScheme` so both apps' ZOKY identity matches
/// exactly. Every other `ColorScheme` slot, `textTheme`, and `cardTheme`
/// passes through unchanged from whatever `Theme.of(context)` already is
/// (`WynTheme.light`/`WynTheme.dark`) -- this is an accent swap, not a
/// second app theme.
class ZokyAccentTheme extends StatelessWidget {
  const ZokyAccentTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final isDark = base.brightness == Brightness.dark;
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          tertiary: WynColors.orange500,
          onTertiary: WynColors.ink,
          tertiaryContainer: isDark ? const Color(0xFF3A1608) : WynColors.orange50,
          onTertiaryContainer: isDark ? const Color(0xFFFFD9C9) : WynColors.ink,
        ),
      ),
      child: child,
    );
  }
}
