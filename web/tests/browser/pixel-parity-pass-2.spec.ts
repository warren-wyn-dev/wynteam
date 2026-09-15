import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("pixel parity pass 2 mirrors current Flutter Beta4 metrics", () => {
  const home = read("app/home.css");
  const homeHeader = read("components/home/home-header.tsx");
  const chrome = read("components/phase3-ui.tsx");
  const nav = read("components/bottom-navigation.tsx");
  const navCss = read("app/bottom-nav.css");
  const css = read("app/pixel-parity-final.css");
  const flutterHome = read("../app/lib/features/home/presentation/home_feed_screen.dart");
  const flutterCard = read("../app/lib/features/home/presentation/widgets/home_drop_card.dart");
  const flutterFollow = read("../app/lib/features/follow/presentation/widgets/follow_action_button.dart");
  const flutterProfile = read("../app/lib/features/profile/presentation/widgets/wynos_founder_profile_header.dart");
  const flutterNav = read("../app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart");
  const flutterRoot = read("../app/lib/features/root/presentation/root_shell.dart");
  const flutterDetail = read("../app/lib/features/drop/presentation/drop_detail_screen.dart");

  expect(flutterHome).toContain("height: 52");
  expect(flutterHome).toContain("Icons.menu, size: 22");
  expect(flutterHome).toContain("count > 9 ? '9+' : '$count'");
  expect(home).toContain(".wyn-home-header {");
  expect(home).toContain("height: 52px");
  // Home caps the notification badge at the source (React), not via a
  // runtime DOM-mutation patch — see docs/wyn-158-visual-parity-audit.md, #4.
  expect(homeHeader).toContain('notificationBadgeCount > 9 ? "9+" : notificationBadgeCount');

  expect(flutterCard).toContain("fontSize: 17.5");
  expect(flutterCard).toContain("fontSize: 17");
  expect(flutterCard).toContain("fontSize: 15");
  expect(flutterCard).toContain("width: WynSpacing.touchTargetMin");
  expect(flutterCard).toContain("Icons.send_outlined");
  expect(flutterFollow).toContain("minimumSize: widget.headerCompact");
  expect(flutterFollow).toContain("horizontal: widget.headerCompact ? 12");
  expect(home).toContain("padding: 0 12px");
  expect(home).toContain("font-size: 13px");
  expect(home).toContain("width: 44px");
  expect(home).toContain("font-size: 15px");

  expect(flutterProfile).toContain("EdgeInsets.symmetric(horizontal: 72)");
  expect(flutterProfile).toContain("color: WynColors.online");
  expect(css).toContain("margin: 7px 72px 0");
  expect(css).toContain("background: #57d65b");

  expect(flutterNav).toContain("Icons.home_rounded");
  expect(flutterNav).toContain("Icons.home_outlined");
  expect(flutterNav).toContain("required this.notificationIcon");
  expect(flutterNav).toContain("required this.selectedNotificationIcon");
  expect(flutterRoot).toContain("Icon(selected ? Icons.notifications : Icons.notifications_outlined)");
  expect(flutterRoot).toContain("notificationIcon: _buildNotificationsIcon(context, selected: false)");
  expect(flutterRoot).toContain("selectedNotificationIcon:");
  expect(flutterRoot).toContain("_buildNotificationsIcon(context, selected: true)");
  expect(flutterNav).toContain("Icons.person_rounded");
  expect(flutterNav).toContain("const SizedBox(height: 6)");
  expect(nav).toContain('type MaterialNavKind = "home" | "search" | "notifications" | "profile" | "add";');
  expect(chrome).toContain('unreadNotificationCount > 9 ? "9+"');
  expect(nav).toContain('kind="home" selected={isActive("/")}');
  expect(nav).toContain('kind="notifications" selected={isActive("/notifications")}');
  expect(navCss).toContain(".route-create-destination");
  expect(navCss).toContain("gap: 6px");

  expect(flutterDetail).toContain("Icons.mode_comment_outlined");
  expect(flutterDetail).toContain("Icons.repeat_rounded");
  expect(flutterDetail).toContain("Icons.ios_share_outlined");
  expect(flutterDetail).toContain("Icons.bookmark_border_rounded");
  expect(css).toContain('button[aria-label="ความคิดเห็น"]::before');
  expect(css).toContain('button[aria-label="แชร์โพสต์"]::before');
  expect(css).toContain('button[aria-label="บันทึกโพสต์"]::before');
  expect(css).toContain("color: #f44336");
  expect(css).toContain("color: var(--graphite)");
});
