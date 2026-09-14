import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("pixel parity pass 2 mirrors current Flutter Beta4 metrics", () => {
  const layout = read("app/layout.tsx");
  const css = read("app/pixel-parity-final.css");
  const chrome = read("components/phase3-ui.tsx");
  const runtime = read("components/pixel-parity-runtime.tsx");
  const flutterHome = read("../app/lib/features/home/presentation/home_feed_screen.dart");
  const flutterCard = read("../app/lib/features/home/presentation/widgets/home_drop_card.dart");
  const flutterFollow = read("../app/lib/features/follow/presentation/widgets/follow_action_button.dart");
  const flutterProfile = read("../app/lib/features/profile/presentation/widgets/wynos_founder_profile_header.dart");
  const flutterNav = read("../app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart");

  expect(layout.lastIndexOf('import "./pixel-parity-final.css";')).toBeGreaterThan(
    layout.lastIndexOf('import "./interaction-parity-final.css";'),
  );
  expect(layout).toContain("<PixelParityRuntime />");

  expect(flutterHome).toContain("height: 52");
  expect(flutterHome).toContain("Icons.menu, size: 22");
  expect(flutterHome).toContain("count > 9 ? '9+' : '$count'");
  expect(css).toContain('.home-header-action[aria-label="เมนู"] > svg');
  expect(css).toContain("width: 22px");
  expect(css).toContain("Icons.chat_bubble_outline");
  expect(runtime).toContain('badge.textContent = "9+"');

  expect(flutterCard).toContain("fontSize: 17.5");
  expect(flutterCard).toContain("fontSize: 17");
  expect(flutterCard).toContain("fontSize: 15");
  expect(flutterCard).toContain("width: WynSpacing.touchTargetMin");
  expect(flutterCard).toContain("Icons.send_outlined");
  expect(flutterFollow).toContain("minHeight: headerCompact");
  expect(flutterFollow).toContain("horizontal: headerCompact ? 12");
  expect(css).toContain("padding: 0 12px");
  expect(css).toContain("font-size: 13px");
  expect(css).toContain("width: 44px");
  expect(css).toContain("font-size: 15px");
  expect(css).toContain("line-height: 1.1");

  expect(flutterProfile).toContain("EdgeInsets.symmetric(horizontal: 72)");
  expect(flutterProfile).toContain("color: WynColors.online");
  expect(css).toContain("margin: 7px 72px 0");
  expect(css).toContain("background: #57d65b");

  expect(flutterNav).toContain("Icons.home_rounded");
  expect(flutterNav).toContain("Icons.home_outlined");
  expect(flutterNav).toContain("Icons.notifications_outlined");
  expect(flutterNav).toContain("Icons.person_rounded");
  expect(flutterNav).toContain("const SizedBox(height: 6)");
  expect(chrome).toContain('type MaterialNavKind = "home" | "search" | "notifications" | "profile" | "add";');
  expect(chrome).toContain('unreadNotificationCount > 9 ? "9+"');
  expect(chrome).toContain('kind="home" selected={activeFor("/")}');
  expect(chrome).toContain('kind="notifications" selected={activeFor("/notifications")}');
  expect(chrome).toContain('kind="profile" selected={activeFor(`/profile/${userId}`)}');
  expect(css).toContain(".route-create-destination");
  expect(css).toContain("gap: 6px");
});
