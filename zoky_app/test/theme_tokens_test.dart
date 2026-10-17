import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/design/zoky_theme.dart';
import 'package:zoky_app/core/design/zoky_tokens.dart';
import 'package:zoky_app/core/design/zoky_typography.dart';
import 'package:zoky_app/core/format/money.dart';

Color _hex(String value) =>
    Color(int.parse('FF${value.replaceFirst('#', '')}', radix: 16));

double _px(String value) => double.parse(value.replaceAll('px', ''));

void main() {
  final theme = buildZokyTheme();

  group('ColorScheme (design 12.1)', () {
    test('primary is Pink Deep #D61256, brand pink kept separately', () {
      expect(theme.colorScheme.primary, const Color(0xFFD61256));
      expect(theme.colorScheme.onPrimary, const Color(0xFFFFFFFF));
      expect(ZokyColors.brand, const Color(0xFFF21967));
      expect(theme.colorScheme.primary, isNot(ZokyColors.brand));
    });

    test('roles map as specified', () {
      final scheme = theme.colorScheme;
      expect(scheme.brightness, Brightness.light);
      expect(scheme.primaryContainer, const Color(0xFFF1E4F5));
      expect(scheme.onPrimaryContainer, const Color(0xFFAF1341));
      expect(scheme.tertiary, const Color(0xFF991636));
      expect(scheme.error, const Color(0xFFB3261E));
      expect(scheme.errorContainer, const Color(0xFFF9DEDC));
      expect(scheme.onErrorContainer, const Color(0xFF410E0B));
      expect(scheme.surface, const Color(0xFFFFFFFF));
      expect(scheme.onSurface, const Color(0xFF16161A));
      expect(scheme.onSurfaceVariant, const Color(0xFF6B6B76));
      expect(scheme.outline, const Color(0xFF8A8A94));
      expect(scheme.outlineVariant, const Color(0xFFEBEBEF));
      expect(scheme.surfaceTint, Colors.transparent);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFE));
      expect(theme.useMaterial3, isTrue);
    });

    test('error is distinct from every brand color', () {
      for (final brand in [
        ZokyColors.brand,
        ZokyColors.brandDeep,
        ZokyColors.berry,
        ZokyColors.wine,
      ]) {
        expect(ZokyColors.error, isNot(brand));
      }
    });
  });

  group('tokens.json stays in sync with the Dart tokens', () {
    final file = File('../design-reference/zoky/tokens.json');
    final available = file.existsSync();
    final Map<String, dynamic> tokens = available
        ? jsonDecode(file.readAsStringSync())
        : const {};

    test('brand, neutral and semantic colors', () {
      final color = tokens['color'] as Map<String, dynamic>;
      String v(String group, String key) =>
          (color[group] as Map<String, dynamic>)[key][r'$value'] as String;

      expect(ZokyColors.brand, _hex(v('brand', 'pink')));
      expect(ZokyColors.brandLight, _hex(v('brand', 'pinkLight')));
      expect(ZokyColors.brandSoft, _hex(v('brand', 'pinkSoft')));
      expect(ZokyColors.brandDeep, _hex(v('brand', 'pinkDeep')));
      expect(ZokyColors.berry, _hex(v('brand', 'berry')));
      expect(ZokyColors.wine, _hex(v('brand', 'wine')));
      expect(ZokyColors.blush, _hex(v('brand', 'blush')));
      expect(ZokyColors.brandLine, _hex(v('brand', 'line')));

      expect(ZokyColors.neutral25, _hex(v('neutral', '25')));
      expect(ZokyColors.neutral50, _hex(v('neutral', '50')));
      expect(ZokyColors.neutral100, _hex(v('neutral', '100')));
      expect(ZokyColors.neutral150, _hex(v('neutral', '150')));
      expect(ZokyColors.neutral200, _hex(v('neutral', '200')));
      expect(ZokyColors.neutral400, _hex(v('neutral', '400')));
      expect(ZokyColors.neutral600, _hex(v('neutral', '600')));
      expect(ZokyColors.neutral900, _hex(v('neutral', '900')));

      expect(ZokyColors.error, _hex(v('semantic', 'error')));
      expect(ZokyColors.success, _hex(v('semantic', 'success')));
      expect(ZokyColors.warning, _hex(v('semantic', 'warning')));
      expect(ZokyColors.info, _hex(v('semantic', 'info')));
      expect(ZokyColors.rating, _hex(v('semantic', 'rating')));
    }, skip: available ? false : 'tokens.json not found');

    test('spacing and radius', () {
      final spacing = tokens['spacing'] as Map<String, dynamic>;
      double s(String key) => _px(spacing[key][r'$value'] as String);
      expect(ZokySpacing.s1, s('1'));
      expect(ZokySpacing.s2, s('2'));
      expect(ZokySpacing.s4, s('4'));
      expect(ZokySpacing.s6, s('6'));
      expect(ZokySpacing.s8, s('8'));
      expect(ZokySpacing.s10, s('10'));
      expect(ZokySpacing.s12, s('12'));
      expect(ZokySpacing.s16, s('16'));
      expect(ZokySpacing.s24, s('24'));
      expect(ZokySpacing.sectionGap, s('sectionGap'));

      final radius = tokens['radius'] as Map<String, dynamic>;
      double r(String key) => _px(radius[key][r'$value'] as String);
      expect(ZokyRadius.xsValue, r('xs'));
      expect(ZokyRadius.smValue, r('sm'));
      expect(ZokyRadius.mdValue, r('md'));
      expect(ZokyRadius.lgValue, r('lg'));
      expect(ZokyRadius.xlValue, r('xl'));
      expect(ZokyRadius.xxlValue, r('2xl'));
    }, skip: available ? false : 'tokens.json not found');
  });

  group('typography (design 5)', () {
    test('Anuphan everywhere with the specified scale', () {
      expect(ZokyTextStyles.fontFamily, 'Anuphan');
      final t = theme.textTheme;
      expect(t.displaySmall!.fontSize, 28);
      expect(t.headlineSmall!.fontSize, 24);
      expect(t.titleLarge!.fontSize, 22);
      expect(t.titleMedium!.fontSize, 18);
      expect(t.bodyLarge!.fontSize, 16);
      expect(t.bodyMedium!.fontSize, 15);
      expect(t.bodySmall!.fontSize, 13);
      expect(t.labelLarge!.fontSize, 16);
      expect(t.labelLarge!.fontWeight, FontWeight.w700);
      expect(t.labelSmall!.fontSize, 12);
      expect(ZokyTextStyles.caption.fontSize, 11);
      for (final style in [t.bodyLarge!, t.titleLarge!, t.labelMedium!]) {
        expect(style.fontFamily, 'Anuphan');
        expect(style.leadingDistribution, TextLeadingDistribution.even);
      }
      // Thai body text needs line height >= 1.45 (design 5.2).
      expect(t.bodyMedium!.height, greaterThanOrEqualTo(1.45));
    });

    test('weights drive the variable font wght axis', () {
      expect(ZokyTextStyles.labelLg.fontVariations, [
        const FontVariation('wght', 700),
      ]);
      final semibold = ZokyTextStyles.weight(
        ZokyTextStyles.bodyMd,
        FontWeight.w600,
      );
      expect(semibold.fontWeight, FontWeight.w600);
      expect(semibold.fontVariations, [const FontVariation('wght', 600)]);
    });
  });

  test('page transitions are native per platform (design 11.2)', () {
    final builders = theme.pageTransitionsTheme.builders;
    expect(
      builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    expect(
      builders[TargetPlatform.android],
      isA<FadeForwardsPageTransitionsBuilder>(),
    );
  });

  test('formatBaht matches the web foodMoney format', () {
    expect(formatBaht(59), '฿59');
    expect(formatBaht(0), '฿0');
    expect(formatBaht(1250), '฿1,250');
    expect(formatBaht(1234567), '฿1,234,567');
    expect(formatBaht(59.5), '฿59.50');
    expect(formatBaht(-40), '-฿40');
  });
}
