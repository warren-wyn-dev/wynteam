import 'package:flutter/material.dart';

import '../design/wyn_colors.dart';
import '../design/wyn_spacing.dart';
import '../design/wyn_typography.dart';

/// Shared visual chrome for WYNOS social surfaces.
///
/// The Founder-approved Profile is the visual north star: paper background,
/// ink-first hierarchy, hairline separation, 44px+ interaction targets,
/// restrained radius, and a narrow readable content rail on wide screens.
/// This file intentionally owns presentation only; it does not own routes,
/// repositories, state, or product behavior.
class WynosSocialChrome {
  WynosSocialChrome._();

  static const double headerHeight = 60;
  static const double tabHeight = 52;
  static const double contentRailMaxWidth = 680;
  static const double searchHeight = 44;
}

/// Keeps phone layouts edge-to-edge while preventing Flutter Web/Desktop
/// social content from stretching across the full browser width.
class WynosContentRail extends StatelessWidget {
  const WynosContentRail({
    super.key,
    required this.child,
    this.maxWidth = WynosSocialChrome.contentRailMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// One header contract for top-level social screens. Leading and trailing
/// slots are fixed to the recommended 48px Material interaction width so the
/// title stays optically centered even when the two actions differ.
class WynosSocialHeader extends StatelessWidget {
  const WynosSocialHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.titleWidget,
    this.showBottomDivider = true,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final Widget? titleWidget;
  final bool showBottomDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: WynosSocialChrome.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2),
      decoration: BoxDecoration(
        color: WynColors.paper,
        border: showBottomDivider
            ? const Border(bottom: BorderSide(color: WynColors.hairline))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: WynSpacing.touchTargetRecommended,
            height: WynSpacing.touchTargetRecommended,
            child: leading,
          ),
          Expanded(
            child: Center(
              child: titleWidget ??
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WynTypography.screenTitle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: WynColors.ink,
                    ),
                  ),
            ),
          ),
          SizedBox(
            width: WynSpacing.touchTargetRecommended,
            height: WynSpacing.touchTargetRecommended,
            child: trailing,
          ),
        ],
      ),
    );
  }
}

/// Text-only tab row used by Home/Notifications and other high-level social
/// surfaces. Tabs divide the available width evenly, matching the calm,
/// predictable navigation rhythm of Profile and large social platforms.
class WynosSocialTabs<T> extends StatelessWidget {
  const WynosSocialTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<WynosSocialTabItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: WynColors.paper,
        border: Border(bottom: BorderSide(color: WynColors.hairline)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _WynosSocialTab<T>(
                item: item,
                selected: item.value == selected,
                onSelected: onSelected,
              ),
            ),
        ],
      ),
    );
  }
}

class WynosSocialTabItem<T> {
  const WynosSocialTabItem({required this.value, required this.label});

  final T value;
  final String label;
}

class _WynosSocialTab<T> extends StatelessWidget {
  const _WynosSocialTab({
    required this.item,
    required this.selected,
    required this.onSelected,
  });

  final WynosSocialTabItem<T> item;
  final bool selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: () => onSelected(item.value),
        child: SizedBox(
          height: WynosSocialChrome.tabHeight,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? WynColors.ink : WynColors.graphite,
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 36,
                height: 2,
                decoration: BoxDecoration(
                  color: selected ? WynColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared visual treatment for a native Flutter [TabBar] when the screen
/// needs TabController/TabBarView behavior. Deliberately text-only: icons in
/// primary tabs add visual noise and make Search feel unlike Home/Profile.
class WynosSocialTabBar extends StatelessWidget
    implements PreferredSizeWidget {
  const WynosSocialTabBar({
    super.key,
    required this.labels,
    this.controller,
  });

  final List<String> labels;
  final TabController? controller;

  @override
  Size get preferredSize => const Size.fromHeight(WynosSocialChrome.tabHeight);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WynColors.paper,
      child: TabBar(
        controller: controller,
        labelColor: WynColors.ink,
        unselectedLabelColor: WynColors.graphite,
        indicatorColor: WynColors.ink,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: WynColors.hairline,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: [for (final label in labels) Tab(text: label)],
      ),
    );
  }
}

/// Search-box shell shared by discovery/search entry points. The caller owns
/// the TextField and behavior; this widget only guarantees the approved
/// neutral fill, hairline border, pill radius and minimum height.
class WynosSearchSurface extends StatelessWidget {
  const WynosSearchSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: WynosSocialChrome.searchHeight,
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
      decoration: BoxDecoration(
        color: WynColors.surfaceTint,
        borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        border: Border.all(color: WynColors.hairline),
      ),
      child: child,
    );
  }
}
