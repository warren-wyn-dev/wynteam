import 'package:flutter/material.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';

/// Heading row of a Home section (Phases 3 and 4): [title] on the left as a
/// semantic heading, "ดูทั้งหมด >" on the right in [ZokyColors.brandDeep]
/// with a 44pt tap target announced as [seeAllLabel].
class ZokyHomeSectionHeader extends StatelessWidget {
  const ZokyHomeSectionHeader({
    super.key,
    required this.title,
    required this.seeAllLabel,
    required this.onSeeAll,
  });

  final String title;
  final String seeAllLabel;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final linkStyle = ZokyTextStyles.labelMd.copyWith(
      color: ZokyColors.brandDeep,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.only(
        left: ZokySpacing.gutter,
        right: ZokySpacing.s4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: ZokyTextStyles.titleSm.copyWith(fontSize: 20),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: seeAllLabel,
            excludeSemantics: true,
            child: InkWell(
              onTap: onSeeAll,
              borderRadius: ZokyRadius.full,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: ZokySizes.tapTargetIos,
                  minWidth: ZokySizes.tapTargetIos,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZokySpacing.s4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ZokyStrings.seeAll, style: linkStyle),
                      const Icon(
                        ZokyIcons.chevronRight,
                        size: 18,
                        color: ZokyColors.brandDeep,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
