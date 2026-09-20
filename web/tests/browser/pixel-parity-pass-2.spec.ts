import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("pixel parity pass 2 keeps product behavior while applying the approved Home mockup", () => {
  const home = read("app/home.css");
  const homeHeader = read("components/home/home-header.tsx");
  const homeTabs = read("components/home/home-tabs.tsx");
  const authorRow = read("components/home/post-author-row.tsx");
  const chrome = read("components/phase3-ui.tsx");
  const nav = read("components/bottom-navigation.tsx");
  const navCss = read("app/bottom-nav.css");
  const css = read("app/pixel-parity-final.css");
  const flutterProfile = read("../app/lib/features/profile/presentation/widgets/wynos_founder_profile_header.dart");
  const flutterNav = read("../app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart");
  const flutterRoot = read("../app/lib/features/root/presentation/root_shell.dart");
  const flutterDetail = read("../app/lib/features/drop/presentation/drop_detail_screen.dart");

  // Founder-approved web Home direction intentionally supersedes the old
  // Flutter Home card/header visual parity while preserving the same actions.
  expect(home).toContain("height: 36px");
  expect(home).toContain("padding-top: min(env(safe-area-inset-top), 20px);");
  expect(home).toContain(".wyn-home-chat-badge");
  expect(home).toContain("width: 7px");
  expect(homeHeader).toContain("notificationBadgeCount > 0");
  expect(homeHeader).toContain("aria-hidden=\"true\"");
  expect(homeTabs).toContain("wyn-home-tab-indicator");
  expect(homeTabs).not.toContain('background: active ? "var(--wyn-surface)"');
  expect(home).toContain("padding: 10px 16px 0");
  expect(home).toContain("font-size: 16px");
  expect(home).toContain("line-height: 1.31");
  expect(home).toContain("font-size: 15px");
  expect(home).toContain("font-size: 14px");
  expect(home).toContain("border-radius: var(--wyn-radius-full);\n  background: var(--wyn-surface);");
  expect(home).toContain(".wyn-post-follow-pill.is-following");
  expect(authorRow).toContain("showFollow && !following");
  expect(authorRow).not.toContain('"กำลังติดตาม"');
  expect(authorRow).toContain('aria-pressed={following || followRequested}');

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

  expect(nav).toContain('type MaterialNavKind = "home" | "club" | "chat" | "profile" | "add";');
  expect(chrome).toContain('unreadNotificationCount > 9 ? "9+"');
  expect(nav).toContain('const homeActive = isActive("/");');
  expect(nav).toContain('kind="home" selected={homeActive}');
  expect(nav).toContain('kind="club" selected={isActive("/clubs")}');
  expect(nav).toContain('kind="chat" selected={isActive("/chat")}');
  expect(nav).toContain('href="/?compose=1"');
  expect(nav).not.toContain('className="route-create-button"');
  expect(navCss).toContain("grid-template-columns: repeat(5, minmax(0, 1fr))");
  expect(navCss).toContain("border-radius: 0");
  expect(navCss).toContain("border-top: 1px solid");
  expect(navCss).toContain("width: 28px");
  expect(home).toContain("width: 120px;");
  expect(navCss).toContain("--wyn-nav-safe-bottom: min(env(safe-area-inset-bottom), 20px);");

  expect(flutterDetail).toContain("Icons.mode_comment_outlined");
  expect(flutterDetail).toContain("Icons.repeat_rounded");
  expect(flutterDetail).toContain("Icons.ios_share_outlined");
  expect(flutterDetail).toContain("Icons.bookmark_border_rounded");
  expect(css).toContain('button[aria-label="ความคิดเห็น"]::before');
  expect(css).toContain('button[aria-label="แชร์โพสต์"]::before');
  expect(css).toContain('button[aria-label="บันทึกโพสต์"]::before');
  expect(css).toContain("color: var(--wyn-accent)");
  expect(css).toContain("color: var(--wyn-text-secondary)");
});
