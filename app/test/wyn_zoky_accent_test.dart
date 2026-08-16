import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/core/design/wyn_colors.dart';
import 'package:wyn/core/design/wyn_theme.dart';
import 'package:wyn/core/design/wyn_zoky_accent.dart';

/// DS-007: [ZokyAccentTheme] is the fix for a real gap DS-007's audit
/// found -- app/'s ZOKY Marketplace screens read `colorScheme.tertiary`
/// for price (see product_detail_screen.dart etc.), but `WynTheme` maps
/// `tertiary` to Cyan (it's WYN Social's bare-link-text color), not
/// Orange, so every ZOKY price was silently rendering Cyan instead of the
/// ZOKY Orange DS-001's own spec calls for. These tests verify the swap
/// actually happens, and that it's scoped to only the wrapped subtree.
void main() {
  testWidgets(
      'wraps its child so Theme.of(context).colorScheme.tertiary resolves to '
      'ZOKY Orange, not WynTheme\'s Cyan', (tester) async {
    Color? tertiary;
    Color? onTertiary;

    await tester.pumpWidget(
      MaterialApp(
        theme: WynTheme.light,
        home: ZokyAccentTheme(
          child: Builder(
            builder: (context) {
              tertiary = Theme.of(context).colorScheme.tertiary;
              onTertiary = Theme.of(context).colorScheme.onTertiary;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(tertiary, WynColors.orange500);
    expect(onTertiary, WynColors.ink);
    // Sanity check this isn't a no-op -- WynTheme.light's own tertiary is
    // Cyan, so the wrapper must have actually changed it.
    expect(WynTheme.light.colorScheme.tertiary, WynColors.cyan500);
  });

  testWidgets(
      'a screen outside ZokyAccentTheme still sees WynTheme\'s Cyan tertiary '
      '-- the swap does not leak app-wide', (tester) async {
    Color? tertiary;

    await tester.pumpWidget(
      MaterialApp(
        theme: WynTheme.light,
        home: Builder(
          builder: (context) {
            tertiary = Theme.of(context).colorScheme.tertiary;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(tertiary, WynColors.cyan500);
  });

  testWidgets('every other ColorScheme slot passes through unchanged',
      (tester) async {
    ColorScheme? scheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: WynTheme.light,
        home: ZokyAccentTheme(
          child: Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(scheme!.primary, WynTheme.light.colorScheme.primary);
    expect(scheme!.surface, WynTheme.light.colorScheme.surface);
    expect(scheme!.outline, WynTheme.light.colorScheme.outline);
  });
}
