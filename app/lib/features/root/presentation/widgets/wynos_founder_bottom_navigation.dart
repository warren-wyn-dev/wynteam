import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wynos_founder_metrics.dart';

class WynosFounderBottomNavigation extends StatelessWidget {
  const WynosFounderBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.createAction,
    required this.notificationIcon,
    required this.selectedNotificationIcon,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget createAction;
  final Widget notificationIcon;
  final Widget selectedNotificationIcon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WynColors.paper,
        border: Border(top: BorderSide(color: WynColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: SizedBox(
          height: WynosFounderMetrics.bottomNavContentHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Destination(
                  label: 'หน้าหลัก',
                  selected: selectedIndex == 0,
                  icon: selectedIndex == 0
                      ? Icons.home_rounded
                      : Icons.home_outlined,
                  onTap: () => onDestinationSelected(0),
                ),
              ),
              Expanded(
                child: _Destination(
                  label: 'ค้นหา',
                  selected: selectedIndex == 1,
                  icon: Icons.search_rounded,
                  onTap: () => onDestinationSelected(1),
                ),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'สร้างโพสต์ใหม่',
                  child: InkResponse(
                    onTap: () => onDestinationSelected(2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        createAction,
                        const SizedBox(height: 6),
                        const Text(
                          'โพสต์',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1,
                            color: WynColors.graphite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _DestinationWidget(
                  label: 'การแจ้งเตือน',
                  selected: selectedIndex == 3,
                  icon: selectedIndex == 3
                      ? selectedNotificationIcon
                      : notificationIcon,
                  onTap: () => onDestinationSelected(3),
                ),
              ),
              Expanded(
                child: _Destination(
                  label: 'โปรไฟล์',
                  selected: selectedIndex == 4,
                  icon: selectedIndex == 4
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  onTap: () => onDestinationSelected(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DestinationWidget(
      label: label,
      selected: selected,
      icon: Icon(icon, size: 28),
      onTap: onTap,
    );
  }
}

class _DestinationWidget extends StatelessWidget {
  const _DestinationWidget({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? WynColors.ink : WynColors.graphite;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        child: IconTheme(
          data: IconThemeData(color: color, size: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
