import 'package:flutter/material.dart';

import '../design/wynos_home_tokens.dart';

/// One row of [WynosMoreMenuButton]'s dropdown.
class WynosMenuAction {
  const WynosMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// WYNOS Home reference spec 4.6 -- the post's `⋯` more-options
/// button, anchored top-right of the post rather than a full-screen
/// bottom sheet: paper background, 1px hairline border, rounded-xl,
/// min-width 148px, a hairline divider between rows only (never after
/// the last one). Flutter's [PopupMenuButton] is the idiomatic widget
/// for "small anchored dropdown near the button that opened it" --
/// closer to the reference's actual layout than a bottom sheet, which
/// is why this replaces the modal-sheet menu the pre-WYNOS card used.
///
/// The spec's own mock only ever lists "แชร์"/"บันทึก" here (section
/// 4.6: "Contains exactly two rows") -- [actions] carries whichever
/// real actions actually apply to a given card (share/save always;
/// hide/report/delete-ReDrop only when relevant), since this app has
/// real moderation features the reference's static mock never needed
/// to model at all.
class WynosMoreMenuButton extends StatelessWidget {
  const WynosMoreMenuButton({super.key, required this.actions});

  final List<WynosMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'เพิ่มเติม',
      // Material's vertical-dots glyph, not the reference's horizontal
      // "⋯" -- kept so this is still the same `Icons.more_vert`
      // IconButton every existing More-menu test already looks up via
      // `find.widgetWithIcon(IconButton, Icons.more_vert)` (PopupMenuButton
      // renders its `icon` as an IconButton internally), rather than
      // rewriting that whole test suite for a one-glyph difference.
      icon: const Icon(
        Icons.more_vert,
        size: 20,
        color: WynosHomeColors.faint,
      ),
      color: WynosHomeColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      // drop-shadow(0 8px 24px rgba(18,18,15,0.12)) -- PopupMenuButton
      // only exposes Material elevation, not an arbitrary BoxShadow;
      // this is the closest approximation that stack affords.
      shadowColor: const Color(0x1F12120F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: WynosHomeColors.hairline),
      ),
      constraints: const BoxConstraints(minWidth: 148),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++) ...[
          PopupMenuItem<int>(
            value: i,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(actions[i].icon, size: 15, color: WynosHomeColors.ink),
                  const SizedBox(width: 10),
                  Text(actions[i].label, style: WynosHomeText.menuItem),
                ],
              ),
            ),
          ),
          if (i != actions.length - 1) const PopupMenuDivider(height: 1),
        ],
      ],
      onSelected: (index) => actions[index].onTap(),
    );
  }
}
