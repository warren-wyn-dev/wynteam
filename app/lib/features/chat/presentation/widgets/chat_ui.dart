import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Shared visual primitives for WYNOS chat surfaces only.
///
/// These intentionally live under Chat rather than the global design system:
/// the Founder approved this denser, monochrome messaging language for Chat
/// while explicitly locking the existing Profile layout.
class ChatPillTab extends StatelessWidget {
  const ChatPillTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? WynColors.ink : WynColors.surfaceTint,
        borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        child: InkWell(
          borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
          onTap: onTap,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
              border: selected ? null : Border.all(color: WynColors.hairline),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? WynColors.paper : WynColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatSearchField extends StatelessWidget {
  const ChatSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
      decoration: BoxDecoration(
        color: WynColors.surfaceTint,
        borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        border: Border.all(color: WynColors.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: WynColors.graphite),
          const SizedBox(width: WynSpacing.space2),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              style: const TextStyle(fontSize: 15.5, color: WynColors.ink),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ).copyWith(
                hintText: hintText,
                hintStyle: const TextStyle(fontSize: 15.5, color: WynColors.mutedNeutral),
              ),
              onChanged: onChanged,
            ),
          ),
          if (controller.text.isNotEmpty && onClear != null)
            Semantics(
              button: true,
              label: 'ล้างคำค้นหา',
              child: InkWell(
                borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.all(WynSpacing.space1),
                  child: Icon(Icons.close, size: 16, color: WynColors.graphite),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatSectionLabel extends StatelessWidget {
  const ChatSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: WynColors.graphite,
      ),
    );
  }
}

/// Chat-only bottom-sheet body matching the approved messaging mockup:
/// paper surface, rounded top corners, compact handle, no trailing chevrons.
class ChatActionSheetBody extends StatelessWidget {
  const ChatActionSheetBody({
    super.key,
    required this.rows,
    this.title,
    this.subtitle,
  });

  final List<Widget> rows;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: WynColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 9, bottom: 8),
                decoration: BoxDecoration(
                  color: WynColors.hairline,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                ),
              ),
            ),
            if (title != null || subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  WynSpacing.space5,
                  WynSpacing.space1,
                  WynSpacing.space5,
                  WynSpacing.space3,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: WynColors.ink,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: const TextStyle(fontSize: 13, color: WynColors.graphite),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  indent: WynSpacing.space5,
                  endIndent: WynSpacing.space5,
                  color: WynColors.hairline,
                ),
              rows[i],
            ],
            const SizedBox(height: WynSpacing.space3),
          ],
        ),
      ),
    );
  }
}

class ChatActionSheetRow extends StatelessWidget {
  const ChatActionSheetRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? WynColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space5,
          vertical: 13,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: WynColors.surfaceTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: foreground),
            ),
            const SizedBox(width: WynSpacing.space3),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatRoundIconButton extends StatelessWidget {
  const ChatRoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.enabled = true,
    this.size = 40,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled && active ? WynColors.ink : WynColors.surfaceTint,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: active ? onPressed : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: 18,
              color: filled && active
                  ? WynColors.paper
                  : (active ? WynColors.ink : WynColors.faint),
            ),
          ),
        ),
      ),
    );
  }
}
