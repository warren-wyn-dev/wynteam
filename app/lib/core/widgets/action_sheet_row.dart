import 'package:flutter/material.dart';

import '../design/wyn_colors.dart';
import '../design/wyn_spacing.dart';

/// One row of a "..." action sheet (report/block/share/mute/hide/delete,
/// ...) -- 21-report-block.tsx's `MainSheet` row shape: icon, label,
/// trailing chevron. Every "..." menu in the app (Drop/Pop/Club
/// post/comment, Profile, Chat) builds its sheet from this instead of a
/// generic `ListTile`, so they all read as one family the way the
/// reference's own report/block rows do.
class ActionSheetRow extends StatelessWidget {
  const ActionSheetRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Overrides the default ink color for both icon and label --
  /// destructive rows (e.g. "ลบ") keep using
  /// `Theme.of(context).colorScheme.error`, same as before this row
  /// widget existed.
  final Color? color;

  /// Shared divider between two rows in the same sheet -- 21-report-
  /// block.tsx's `<div className="h-px mx-6" .../>` between MainSheet's
  /// two buttons.
  static const divider = Divider(
    height: 1,
    indent: WynSpacing.space6,
    endIndent: WynSpacing.space6,
    color: WynColors.hairline,
  );

  @override
  Widget build(BuildContext context) {
    final rowColor = color ?? WynColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space6,
          vertical: WynSpacing.space4,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: rowColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: rowColor,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: WynColors.faint),
          ],
        ),
      ),
    );
  }
}

/// The small pill at the top of a modal bottom sheet, signaling it's
/// swipe-dismissible -- 21-report-block.tsx's `Sheet` wrapper (and
/// already established by ReportSheet/ShareSheet's own inline copies of
/// this same shape) draws one at the top of every sheet in this design.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
        decoration: BoxDecoration(
          color: WynColors.hairline,
          borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        ),
      ),
    );
  }
}

/// Lays out [rows] (each already-conditionally-built by the caller) with
/// [ActionSheetRow.divider] between them (never after the last one),
/// under a [SheetDragHandle] and inside a [SafeArea] -- the common shape
/// every "..." action sheet in the app now shares. Callers still own
/// their own `showModalBottomSheet` call (targetType/onTap closures
/// differ too much to also share) -- this is just the repeated
/// handle+divider+padding scaffolding around whatever rows they pass in.
class ActionSheetBody extends StatelessWidget {
  const ActionSheetBody({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetDragHandle(),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) ActionSheetRow.divider,
            rows[i],
          ],
          const SizedBox(height: WynSpacing.space4),
        ],
      ),
    );
  }
}
