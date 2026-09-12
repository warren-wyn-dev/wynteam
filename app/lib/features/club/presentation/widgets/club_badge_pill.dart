import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../data/club_member_badge.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// WYN-129 -- the badge pill (`.badge-pill`) shown next to a member's
/// name in the Members tab and next to a post/comment author's name.
/// Deliberately a distinct, visibly-smaller component from the role
/// `Chip` `ClubMembersTab` already draws -- Design Rules: "ห้ามใช้ role
/// Chip เดิมกับ badge ปนกัน". Never carries any permission meaning.
class ClubBadgePill extends StatelessWidget {
  const ClubBadgePill({super.key, required this.badge});

  final ClubMemberBadge badge;

  static ({Color background, Color foreground}) _colorsFor(ClubBadgeColor color) {
    switch (color) {
      case ClubBadgeColor.gold:
        return (background: WynColors.clubBadgeGoldBg, foreground: WynColors.clubBadgeGoldFg);
      case ClubBadgeColor.sage:
        return (background: WynColors.clubBadgeSageBg, foreground: WynColors.clubBadgeSageFg);
      case ClubBadgeColor.plum:
        return (background: WynColors.clubBadgePlumBg, foreground: WynColors.clubBadgePlumFg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(badge.colorKey);
    return Semantics(
      // Accessibility: "อ่านได้ด้วย screen reader เป็น 'ป้าย: [ข้อความ]'
      // แยกจาก role เพื่อไม่ให้สับสนว่าเป็นสิทธิ์".
      label: 'ป้าย: ${badge.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2, vertical: 2),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        ),
        child: BrowserSystemText(
          badge.label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.foreground),
        ),
      ),
    );
  }
}

/// Set/edit-badge dialog -- Design's Components: "ช่องกรอกข้อความ (max 20
/// ตัวอักษร, กันข้อความว่าง) + 3 ตัวเลือกสีเป็นวงกลมให้แตะเลือก (ไม่ใช่
/// color picker อิสระ) + ปุ่มยืนยัน/ยกเลิก". Returns the (label, color)
/// pair, or null if cancelled.
Future<(String, ClubBadgeColor)?> showSetClubBadgeDialog(
  BuildContext context, {
  String initialLabel = '',
  ClubBadgeColor initialColor = ClubBadgeColor.gold,
}) {
  return showDialog<(String, ClubBadgeColor)>(
    context: context,
    builder: (dialogContext) => _SetClubBadgeDialog(
      initialLabel: initialLabel,
      initialColor: initialColor,
    ),
  );
}

class _SetClubBadgeDialog extends StatefulWidget {
  const _SetClubBadgeDialog({required this.initialLabel, required this.initialColor});

  final String initialLabel;
  final ClubBadgeColor initialColor;

  @override
  State<_SetClubBadgeDialog> createState() => _SetClubBadgeDialogState();
}

class _SetClubBadgeDialogState extends State<_SetClubBadgeDialog> {
  // Owned by this State (not a bare local variable disposed manually
  // right after showDialog resolves) -- see WYN-127's
  // _ClubChannelNameDialog for the exact "TextEditingController used
  // after being disposed" pitfall this avoids.
  late final _controller = TextEditingController(text: widget.initialLabel);
  late ClubBadgeColor _selectedColor = widget.initialColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _controller.text.trim();
    final isValid = trimmed.isNotEmpty && trimmed.length <= 20;

    return AlertDialog(
      title: const BrowserSystemText('ตั้งป้าย'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrowserSystemTextField(
            controller: _controller,
            autofocus: true,
            maxLength: 20,
            decoration: const InputDecoration(hint: BrowserSystemText('ข้อความป้าย เช่น VIP')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: WynSpacing.space2),
          Row(
            children: [
              for (final color in ClubBadgeColor.values) ...[
                _ColorChoiceCircle(
                  color: color,
                  selected: color == _selectedColor,
                  onTap: () => setState(() => _selectedColor = color),
                ),
                const SizedBox(width: WynSpacing.space3),
              ],
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const BrowserSystemText('ยกเลิก'),
        ),
        TextButton(
          onPressed:
              isValid ? () => Navigator.of(context).pop((trimmed, _selectedColor)) : null,
          child: const BrowserSystemText('บันทึก'),
        ),
      ],
    );
  }
}

class _ColorChoiceCircle extends StatelessWidget {
  const _ColorChoiceCircle({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final ClubBadgeColor color;
  final bool selected;
  final VoidCallback onTap;

  static const _labels = {
    ClubBadgeColor.gold: 'สีทอง',
    ClubBadgeColor.sage: 'สีเขียวเซจ',
    ClubBadgeColor.plum: 'สีม่วงพลัม',
  };

  @override
  Widget build(BuildContext context) {
    final fill = switch (color) {
      ClubBadgeColor.gold => WynColors.clubBadgeGoldBg,
      ClubBadgeColor.sage => WynColors.clubBadgeSageBg,
      ClubBadgeColor.plum => WynColors.clubBadgePlumBg,
    };
    return Semantics(
      label: _labels[color],
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('club_badge_color_${color.name}'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: WynSpacing.touchTargetMin,
          height: WynSpacing.touchTargetMin,
          alignment: Alignment.center,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? WynColors.sapphire : WynColors.hairline,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 16, color: WynColors.ink)
                : null,
          ),
        ),
      ),
    );
  }
}
