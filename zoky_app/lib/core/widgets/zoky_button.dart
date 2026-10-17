import 'package:flutter/material.dart';

import '../adaptive/adaptive.dart';
import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';

enum ZokyButtonVariant {
  primary,
  outlineBrand,
  soft,
  outlineNeutral,
  destructive,
  text,
}

enum ZokyButtonSize { sm, md, lg }

/// Pill button (design 9.1, web `fx-btn`). Shared on every platform.
///
/// While [loading], the label is replaced by a spinner at the same width and
/// taps are ignored (no double submit).
class ZokyButton extends StatelessWidget {
  const ZokyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ZokyButtonVariant.primary,
    this.size = ZokyButtonSize.md,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  /// Convenience for the primary CTA.
  const ZokyButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = ZokyButtonSize.md,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = ZokyButtonVariant.primary;

  final String label;
  final VoidCallback? onPressed;
  final ZokyButtonVariant variant;
  final ZokyButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;

  double get _height => switch (size) {
    ZokyButtonSize.sm => ZokySizes.buttonSm,
    ZokyButtonSize.md => ZokySizes.buttonMd,
    ZokyButtonSize.lg => ZokySizes.buttonLg,
  };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (Color bg, Color fg, BorderSide side) = _colors(enabled);
    final horizontal = size == ZokyButtonSize.sm ? 16.0 : 22.0;

    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      style: ZokyTextStyles.labelLg.copyWith(color: fg),
    );
    final Widget content = loading
        ? ZokySpinner(size: 20, color: fg)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: ZokySizes.iconMd, color: fg),
                const SizedBox(width: ZokySpacing.s4),
              ],
              Flexible(child: labelText),
            ],
          );

    final hasBrandShadow = variant == ZokyButtonVariant.primary && enabled;

    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? label : null,
      excludeSemantics: loading,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: _height,
          minWidth: expand ? double.infinity : 64,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: ZokyRadius.full,
            boxShadow: hasBrandShadow ? ZokyShadows.brand : null,
          ),
          child: Material(
            color: bg,
            shape: StadiumBorder(side: side),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              highlightColor: _pressedOverlay,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontal,
                  vertical: ZokySpacing.s4,
                ),
                child: Center(widthFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color get _pressedOverlay => switch (variant) {
    ZokyButtonVariant.primary => ZokyColors.actionPressed,
    ZokyButtonVariant.outlineBrand => ZokyColors.blush,
    ZokyButtonVariant.destructive => ZokyColors.errorContainer,
    _ => ZokyColors.neutral100,
  };

  (Color, Color, BorderSide) _colors(bool enabled) {
    if (!enabled) {
      final disabledSide = switch (variant) {
        ZokyButtonVariant.outlineBrand ||
        ZokyButtonVariant.outlineNeutral ||
        ZokyButtonVariant.destructive => const BorderSide(
          color: ZokyColors.borderDefault,
        ),
        _ => BorderSide.none,
      };
      final disabledBg = variant == ZokyButtonVariant.text
          ? Colors.transparent
          : (disabledSide == BorderSide.none
                ? ZokyColors.actionDisabledBg
                : ZokyColors.surface);
      return (disabledBg, ZokyColors.actionDisabledText, disabledSide);
    }
    return switch (variant) {
      ZokyButtonVariant.primary => (
        ZokyColors.actionPrimary,
        ZokyColors.onAction,
        BorderSide.none,
      ),
      ZokyButtonVariant.outlineBrand => (
        ZokyColors.surface,
        ZokyColors.actionPrimary,
        const BorderSide(color: ZokyColors.actionPrimary, width: 1.5),
      ),
      ZokyButtonVariant.soft => (
        ZokyColors.blush,
        ZokyColors.berry,
        const BorderSide(color: ZokyColors.brandLine, width: 1.5),
      ),
      ZokyButtonVariant.outlineNeutral => (
        ZokyColors.surface,
        ZokyColors.textPrimary,
        const BorderSide(color: ZokyColors.borderDefault),
      ),
      ZokyButtonVariant.destructive => (
        ZokyColors.surface,
        ZokyColors.error,
        const BorderSide(color: ZokyColors.error, width: 1.5),
      ),
      ZokyButtonVariant.text => (
        Colors.transparent,
        ZokyColors.textLink,
        BorderSide.none,
      ),
    };
  }
}
