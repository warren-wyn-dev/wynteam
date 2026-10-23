import 'package:flutter/widgets.dart';

import '../design/zoky_tokens.dart';

/// Responsive store-card grid as a sliver: 2 columns, 3 at >=680px, 1 at
/// text scale >=1.5 (design 6.4 / 10.2). Rows size to their tallest card,
/// so long Thai names never overflow a fixed cell height.
///
/// Shared by the legacy Home body and the store search screen.
class ZokyStoreGrid extends StatelessWidget {
  const ZokyStoreGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = scale >= 1.5 ? 1 : (width >= 680 ? 3 : 2);
    final gap = width <= 359 ? ZokySpacing.s4 : ZokySpacing.s6;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: ZokySpacing.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: gap),
                Expanded(
                  child: i + c < children.length
                      ? children[i + c]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.gutter),
      sliver: SliverList.list(children: rows),
    );
  }
}
