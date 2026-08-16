import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';

/// Local theme override applied at the root of every ZOKY screen that
/// renders a price (or anything else keyed off `colorScheme.tertiary`)
/// so it resolves to ZOKY Orange (`WynColors.orange500`) instead of WYN
/// Social's Cyan.
///
/// Background (see .wyn/tasks/bugs/DS-001c-zoky-price-color-not-orange-in-app.md
/// and .wyn/docs/design/ds-001-color-system.md, Section 4's "`app/` — จุดที่
/// ต้องระวังเป็นพิเศษ" subsection): `app/` has a single `MaterialApp`/
/// `WynTheme` shared by every Bottom Nav tab (Home/Drop/Pop/Profile/ZOKY).
/// `WynColors.socialLightScheme`/`socialDarkScheme` set `tertiary =
/// cyan500`, so reading `Theme.of(context).colorScheme.tertiary` anywhere
/// in `app/` -- including inside the ZOKY tab -- resolves to Cyan, never
/// Orange. Unlike `seller_app/` (a separate app/binary that can swap its
/// *entire* theme to `ZokyTheme`,
/// seller_app/lib/core/design/wyn_zoky_theme.dart), there is no mechanism
/// for a single Bottom Nav tab's subtree in `app/` to override `tertiary`
/// automatically for screens pushed on top of it via `Navigator.push` --
/// pushed routes are inserted as new, sibling `Overlay` entries, so they
/// do NOT inherit a `Theme` wrapped only around the ZOKY tab's root
/// widget inside `RootShell`'s `IndexedStack`. So every ZOKY screen that
/// needs Orange wraps its own `Scaffold` with this scope instead of
/// relying on a single wrap higher in the tree.
///
/// Mirrors `ZokyTheme`'s `tertiary`/`onTertiary`/`tertiaryContainer`/
/// `onTertiaryContainer` override exactly (DS-001, Section 3.4) so both
/// apps resolve the same 4 slots to the same values -- everything else
/// (`primary`, `surface`, `outline`, typography) is untouched, so WYN
/// Social's Cyan accent/branding elsewhere in these same screens (e.g.
/// store avatar background, "ยอดรวม" total) is unaffected.
class ZokyThemeScope extends StatelessWidget {
  const ZokyThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final isDark = baseTheme.brightness == Brightness.dark;

    return Theme(
      data: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(
          tertiary: WynColors.orange500,
          onTertiary: WynColors.ink,
          // Not named 2.x tokens in wyn_colors.dart for the dark shade --
          // copied verbatim from DS-001 Section 3.4's ZOKY dark
          // tertiaryContainer/onTertiaryContainer values, same as
          // seller_app/lib/core/design/wyn_zoky_theme.dart's ZokyTheme.
          tertiaryContainer: isDark ? const Color(0xFF3A1608) : WynColors.orange50,
          onTertiaryContainer: isDark ? const Color(0xFFFFD9C9) : WynColors.ink,
        ),
      ),
      child: child,
    );
  }
}
