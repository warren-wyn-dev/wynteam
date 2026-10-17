import 'package:flutter/material.dart';

import '../design/zoky_colors.dart';
import '../design/zoky_tokens.dart';
import '../design/zoky_typography.dart';

enum ZokyChipSelectedStyle { solid, soft }

/// Filter chip (design 9.3, web `fx-chip`). 40 visual height, padded to a
/// 48 tap target. Selected solid = action.primary + white (never #F21967);
/// selected soft = Blush + Berry + brand.pink border.
class ZokyChip extends StatelessWidget {
  const ZokyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedStyle = ZokyChipSelectedStyle.solid,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final ZokyChipSelectedStyle selectedStyle;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final BorderSide side;
    if (!selected) {
      bg = ZokyColors.surface;
      fg = ZokyColors.textPrimary;
      side = const BorderSide(color: ZokyColors.borderDefault);
    } else if (selectedStyle == ZokyChipSelectedStyle.solid) {
      bg = ZokyColors.actionPrimary;
      fg = ZokyColors.onAction;
      side = const BorderSide(color: ZokyColors.actionPrimary);
    } else {
      bg = ZokyColors.blush;
      fg = ZokyColors.berry;
      side = const BorderSide(color: ZokyColors.brand, width: 1.5);
    }

    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        // 40 visual + 4 + 4 = 48dp touch target.
        padding: const EdgeInsets.symmetric(vertical: ZokySpacing.s2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ZokySizes.buttonSm),
          child: Material(
            color: bg,
            shape: StadiumBorder(side: side),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSelected,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZokySpacing.s8,
                  vertical: ZokySpacing.s3,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZokyTextStyles.labelMd.copyWith(color: fg),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
