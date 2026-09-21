import { readFile } from "node:fs/promises";
import path from "node:path";

import { expect, test } from "@playwright/test";

test("signed-out root redirects to the new pixel-matched Welcome", async ({ page }) => {
  await page.goto("/", { waitUntil: "networkidle" });
  await expect(page).toHaveURL(/\/welcome$/);
  await expect(page.getByText("ทุกเรื่องราว มีจุดเริ่มต้น", { exact: true })).toBeVisible();
  await expect(page.getByText("Welcome to WYNOS.", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "สร้างบัญชีใหม่" })).toBeVisible();
  await expect(page.getByRole("button", { name: "เข้าสู่ระบบด้วย Google" })).toBeVisible();
  await expect(page.getByRole("button", { name: "เข้าสู่ระบบ", exact: true })).toBeVisible();
  await expect(page.getByText(/Next\.js Web รุ่นทดสอบภายใน/)).toHaveCount(0);
});

test("Welcome continues into the real email sign-up and login flows", async ({ page }) => {
  await page.goto("/welcome", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "สร้างบัญชีใหม่" }).click();
  await expect(page).toHaveURL(/\/signup\/step-1$/);
  await expect(page.getByText("สร้างบัญชี", { exact: true })).toBeVisible();

  await page.goto("/welcome", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "เข้าสู่ระบบ", exact: true }).click();
  await expect(page).toHaveURL(/\/login$/);
  await expect(page.locator('input[name="loginIdentifier"]')).toBeVisible();
  await expect(page.locator('input[name="loginPassword"]')).toBeVisible();
});

test("source contracts cannot regress to staged migration UI", async () => {
  const root = process.cwd();
  const [
    gate,
    auth,
    home,
    homeCss,
    postAuthorRow,
    postActions,
    homeTabs,
    pageSource,
    routeUi,
    finalCss,
    completionCss,
    closureCss,
    postDetailCss,
    profileGoldenCss,
    goldenDrop,
    goldenDropCss,
    search,
    profile,
    profileParity,
    followList,
    chat,
    notifications,
    settings,
    clubs,
    clubGolden,
    clubGoldenCss,
    clubPage,
    layout,
    postDetail,
    dropPage,
  ] = await Promise.all([
    readFile(path.join(root, "components/developer-route-gate.tsx"), "utf8"),
    readFile(path.join(root, "components/parity-auth-entry.tsx"), "utf8"),
    readFile(path.join(root, "components/home/home-screen.tsx"), "utf8"),
    readFile(path.join(root, "app/home.css"), "utf8"),
    readFile(path.join(root, "components/home/post-author-row.tsx"), "utf8"),
    readFile(path.join(root, "components/home/post-actions.tsx"), "utf8"),
    readFile(path.join(root, "components/home/home-tabs.tsx"), "utf8"),
    readFile(path.join(root, "app/page.tsx"), "utf8"),
    readFile(path.join(root, "components/phase3-ui.tsx"), "utf8"),
    readFile(path.join(root, "app/parity-final.css"), "utf8"),
    readFile(path.join(root, "app/parity-completion.css"), "utf8"),
    readFile(path.join(root, "app/parity-closure.css"), "utf8"),
    readFile(path.join(root, "app/post-detail-parity.css"), "utf8"),
    readFile(path.join(root, "app/profile-golden-final.css"), "utf8"),
    readFile(path.join(root, "components/golden-drop-card.tsx"), "utf8"),
    readFile(path.join(root, "app/golden-drop-card.css"), "utf8"),
    readFile(path.join(root, "components/search-route.tsx"), "utf8"),
    readFile(path.join(root, "components/profile-route.tsx"), "utf8"),
    readFile(path.join(root, "components/profile-parity-route.tsx"), "utf8"),
    readFile(path.join(root, "components/profile-follow-list-route.tsx"), "utf8"),
    readFile(path.join(root, "components/chat-routes.tsx"), "utf8"),
    readFile(path.join(root, "components/notifications-route.tsx"), "utf8"),
    readFile(path.join(root, "components/settings-route.tsx"), "utf8"),
    readFile(path.join(root, "components/clubs-routes.tsx"), "utf8"),
    readFile(path.join(root, "components/club-detail-golden.tsx"), "utf8"),
    readFile(path.join(root, "app/club-detail-golden.css"), "utf8"),
    readFile(path.join(root, "app/club/[id]/page.tsx"), "utf8"),
    readFile(path.join(root, "app/layout.tsx"), "utf8"),
    readFile(path.join(root, "components/post-detail-route.tsx"), "utf8"),
    readFile(path.join(root, "app/drop/[id]/page.tsx"), "utf8"),
  ]);

  expect(gate).not.toContain("is_developer_account");
  expect(gate).not.toContain("บัญชีนักพัฒนา");
  expect(auth).toContain("<HomeScreen session={session} />");
  expect(auth).not.toContain("HomeMigrationPreview");
  expect(pageSource).not.toContain("HomeNavigationBridge");
  expect(layout).not.toContain("DrawerRouteAdapter");
  for (const sheet of ["profile-golden-final.css", "club-detail-golden.css", "golden-drop-card.css", "home.css"]) expect(layout).toContain(sheet);

  for (const label of ["สำหรับคุณ", "กำลังติดตาม", "คลับของฉัน"]) expect(homeTabs).toContain(label);
  expect(homeTabs).not.toContain("กำลังนิยม");
  expect(homeTabs).toContain("wyn-home-tab-indicator");
  const homeHeader = await readFile(path.join(root, "components/home/home-header.tsx"), "utf8");
  expect(homeHeader).toContain('/wynos_logo_mark.png');
  const homeDrawer = await readFile(path.join(root, "components/home/home-drawer.tsx"), "utf8");
  for (const label of ["สำรวจ Club", "สร้าง Club", "Club ของฉัน", "บันทึกไว้", "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก"]) expect(homeDrawer).toContain(label);
  for (const contract of [
    "Quote ReDrop", "ไม่สนใจโพสต์นี้", "เลิกทำ", "submit_report", 'from("feed_signals")',
    // WYN-185 item 5: every "แชร์" call site was centralized onto the shared
    // navigator.share()-with-clipboard-fallback helper -- home-screen.tsx no
    // longer calls navigator.share() directly, it calls shareOrCopyLink().
    "shareOrCopyLink", "toggleClubPostLike", "toggleAuthorFollow", "onShare",
  ]) expect(home).toContain(contract);
  expect(postActions).toContain("<WynosShareIcon size={22} />");
  expect(postActions).toContain('<WynosIcon name="repost" size={22} strokeWidth={2} />');
  expect(postActions).toContain('<WynosIcon name="bookmark" size={22} strokeWidth={2}');
  expect(postAuthorRow).toContain("ขอติดตามแล้ว");
  expect(postAuthorRow).toContain("showFollow && !following");
  expect(postAuthorRow).not.toContain('"กำลังติดตาม"');
  const homePostCard = await readFile(path.join(root, "components/home/home-post-card.tsx"), "utf8");
  expect(homePostCard).toContain('รีโพสต์โดย {row.redropper_username || "WYNOS"}');
  expect(homePostCard).not.toContain("รีโพสต์โดย @");
  expect(homePostCard).toContain('row.audience == null || row.audience === "everyone"');
  expect(home).not.toContain('location.assign');
  for (const contract of [
    "wyn-post-follow-pill",
    "border-radius: var(--wyn-radius-full);\n  background: var(--wyn-surface);",
    ".wyn-post-follow-pill.is-following",
    "font-size: 16px",
    "max-width: 96px",
    "gap: 26px",
  ]) expect(homeCss).toContain(contract);

  const bottomNav = await readFile(path.join(root, "components/bottom-navigation.tsx"), "utf8");
  const bottomNavCss = await readFile(path.join(root, "app/bottom-nav.css"), "utf8");
  for (const label of ["หน้าหลัก", "คลับ", "โพสต์", "แชท", "โปรไฟล์"]) expect(bottomNav).toContain(label);
  expect(bottomNav).toContain('href="/clubs"');
  expect(bottomNav).toContain('href="/chat"');
  expect(bottomNav).toContain('href="/?compose=1"');
  expect(bottomNav).not.toContain('className="route-create-button"');
  expect(bottomNavCss).toContain("width: min(100%, 680px)");
  expect(bottomNavCss).toContain("font-size: 10px");
  expect(bottomNavCss).toContain("border-top: 1px solid");
  expect(routeUi).toContain("GoldenDropCard");

  expect(search).toContain('headerMode="hidden"');
  expect(search).toContain("แฮชแท็กกำลังนิยม");
  expect(search).toContain("แนะนำให้ติดตาม");
  expect(search).not.toContain("กำลังเติบโต");
  for (const label of ["User", "โพสต์", "Club"]) expect(search).toContain(label);

  for (const label of ["สื่อ", "รีโพสต์", "ถูกใจ", "แก้ไขโปรไฟล์", "ส่งข้อความ"]) expect(profile).toContain(label);
  expect(profile).toContain("ProfileRecommendations");
  expect(profile).toContain('headerMode="hidden"');
  for (const label of ["ผู้ติดตาม", "รายงาน", "ปิดเสียง", "บล็อก"]) expect(profileParity).toContain(label);
  expect(profileParity).toContain('submit_report');
  for (const label of ["ผู้ติดตาม", "กำลังติดตาม"]) expect(followList).toContain(label);
  expect(followList).toContain('toggleAuthorFollow');
  expect(followList).toContain('kind === "followers"');
  expect(profileGoldenCss).not.toContain("height: calc(170px");
  for (const metric of ["font-size: 17px", "min-height: 44px", "height: calc(52px + env(safe-area-inset-top))"]) expect(profileGoldenCss).toContain(metric);
  for (const contract of ["toggleDropLike", "toggleDropSave", "toggleDropRedrop", "drop_view_count", "Quote ReDrop", "submit_report", 'from("drop_images")']) expect(goldenDrop).toContain(contract);
  expect(goldenDropCss).toContain("font-size: 17.5px");
  expect(goldenDropCss).toContain("min-height: 48px");

  expect(chat).toContain("ทั้งหมด");
  expect(chat).toContain("ยังไม่อ่าน");
  expect(chat).toContain("คำขอข้อความ");
  expect(chat).not.toContain("setRequestMode");
  expect(notifications).toContain("ทั้งหมด");
  expect(notifications).toContain("การกล่าวถึง");
  expect(notifications).toContain("markAllNotificationsRead");

  for (const label of ["บัญชี", "ความเป็นส่วนตัว", "การตั้งค่าแอป", "การแจ้งเตือน", "ธีมเข้ม", "ช่วยเหลือ", "ข้อกำหนดและความเป็นส่วนตัว", "ออกจากระบบ"]) expect(settings).toContain(label);
  expect(settings).toContain("Web Beta1");

  for (const label of ["เจอคอมมูนิตี้ที่ใช่", "สำหรับคุณ", "ค้นหา Club", "กำลังนิยม", "ใหม่ล่าสุด", "รออนุมัติ", "Club ของฉัน", "สร้าง Club"]) expect(clubs).toContain(label);
  expect(clubs).not.toContain("Club แนะนำสำหรับคุณ");
  expect(clubPage).toContain("ClubDetailGoldenRoute");
  for (const label of ["โพสต์", "แชท", "เกี่ยวกับ", "รายละเอียด", "สมาชิก", "กิจกรรม", "Insights", "เข้าร่วม", "รออนุมัติ", "รายงาน Club", "ปิดการแจ้งเตือน Club นี้", "บันทึก", "ปักหมุด"]) expect(clubGolden).toContain(label);
  for (const contract of ["fetchClubPostsForClub", "toggleClubPostSave", "toggleClubPostPin", "voteClubPostPoll", 'from("club_channels")', 'from("club_channel_messages")', 'from("club_events")', "mark_club_channel_read", "club_notification_mutes", 'rpc("club_insights"', "submit_report"]) expect(clubGolden).toContain(contract);
  expect(clubGolden).toContain(`${"${clubId}"}/chat/${"${channelId}"}/${"${userId}"}-${"${Date.now()}"}`);
  expect(clubGoldenCss).toContain("height: 140px");
  expect(clubGoldenCss).toContain("grid-template-columns: repeat(3, 1fr)");
  expect(clubGoldenCss).toContain("font-size: 17px");

  expect(dropPage).toContain("PostDetailRoute");
  for (const label of ["ความคิดเห็น", "แชร์โพสต์", "ดูกิจกรรม", "กิจกรรมโพสต์", "ถูกใจ", "รีโพสต์", "ตอบกลับ", "ดูคอมเมนต์เพิ่มเติม"]) expect(postDetail).toContain(label);
  expect(postDetail).not.toContain('>ทั้งหมด<');
  expect(postDetail).toContain('showBottomNav={false}');
  expect(postDetail).toContain('from("drop_images")');
  expect(postDetailCss).toContain("height: 54px");
  expect(postDetailCss).toContain("height: 46px");
  expect(postDetailCss).toContain("border-radius: 18px");
  expect(postDetailCss).toContain("grid-template-columns: repeat(5, 1fr)");

  for (const metric of [
    "--wyn-social-header: 60px", "--wyn-social-tab: 52px", "--wyn-social-search: 44px",
    "--wyn-profile-cover: 170px", "--wyn-profile-action: 44px", "--wyn-detail-media-radius: 18px",
    "--wyn-detail-activity: 54px", "--wyn-comment-composer: 46px",
  ]) expect(finalCss).toContain(metric);
  expect(completionCss).not.toContain("height: calc(170px");
  for (const contract of ["height: 44px", "height: 52px", "min-height: 54px", "min-height: 46px"]) expect(completionCss).toContain(contract);
  expect(closureCss).toContain("profile-recommendation-card");
  expect(closureCss).toContain("settings-version-footer");
});
