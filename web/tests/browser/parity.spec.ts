import { readFile } from "node:fs/promises";
import path from "node:path";

import { expect, test } from "@playwright/test";

test("signed-out Welcome mirrors the Flutter golden master", async ({ page }) => {
  await page.goto("/", { waitUntil: "networkidle" });
  await expect(page.getByRole("heading", { name: "WYNOS" })).toBeVisible();
  await expect(page.getByText("BETA", { exact: true })).toBeVisible();
  await expect(page.getByText("เชื่อมต่อ แสดงตัวตน และสร้างชุมชนของคุณเอง", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "เริ่มต้นใช้งาน" })).toBeVisible();
  await expect(page.getByText(/Next\.js Web รุ่นทดสอบภายใน/)).toHaveCount(0);

  const metrics = await page.evaluate(() => {
    const title = document.querySelector<HTMLElement>(".parity-wordmark-line h1");
    const cta = document.querySelector<HTMLElement>(".parity-welcome-cta");
    if (!title || !cta) return null;
    return {
      titleSize: getComputedStyle(title).fontSize,
      titleWeight: getComputedStyle(title).fontWeight,
      ctaHeight: cta.getBoundingClientRect().height,
    };
  });
  expect(metrics).not.toBeNull();
  expect(metrics!.titleSize).toBe("34px");
  expect(Number(metrics!.titleWeight)).toBe(500);
  expect(metrics!.ctaHeight).toBeGreaterThanOrEqual(56);
});

test("Welcome continues to the original auth-method and email flows", async ({ page }) => {
  await page.goto("/", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "เริ่มต้นใช้งาน" }).click();
  await expect(page.getByRole("heading", { name: "เข้าสู่ระบบ WYNOS" })).toBeVisible();
  await expect(page.getByRole("button", { name: "เข้าสู่ระบบด้วย Google" })).toBeVisible();
  await expect(page.getByRole("button", { name: "เข้าสู่ระบบด้วยอีเมล" })).toBeVisible();
  await page.getByRole("button", { name: "เข้าสู่ระบบด้วยอีเมล" }).click();
  await expect(page.getByText("สมัครสมาชิก", { exact: true }).first()).toBeVisible();
  await expect(page.getByLabel("อีเมล")).toBeVisible();
  await expect(page.getByLabel("รหัสผ่าน")).toBeVisible();
  await expect(page.getByText("อย่างน้อย 6 ตัวอักษร", { exact: true })).toBeVisible();
});

test("source contracts cannot regress to staged migration UI", async () => {
  const root = process.cwd();
  const [
    gate,
    auth,
    home,
    pageSource,
    routeUi,
    finalCss,
    completionCss,
    closureCss,
    postDetailCss,
    homeGoldenCss,
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
    clubDetail,
    clubGolden,
    clubGoldenCss,
    clubPage,
    layout,
    postDetail,
    dropPage,
  ] = await Promise.all([
    readFile(path.join(root, "components/developer-route-gate.tsx"), "utf8"),
    readFile(path.join(root, "components/parity-auth-entry.tsx"), "utf8"),
    readFile(path.join(root, "components/parity-home-final.tsx"), "utf8"),
    readFile(path.join(root, "app/page.tsx"), "utf8"),
    readFile(path.join(root, "components/phase3-ui.tsx"), "utf8"),
    readFile(path.join(root, "app/parity-final.css"), "utf8"),
    readFile(path.join(root, "app/parity-completion.css"), "utf8"),
    readFile(path.join(root, "app/parity-closure.css"), "utf8"),
    readFile(path.join(root, "app/post-detail-parity.css"), "utf8"),
    readFile(path.join(root, "app/home-golden-final.css"), "utf8"),
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
    readFile(path.join(root, "components/club-detail-route.tsx"), "utf8"),
    readFile(path.join(root, "components/club-detail-golden.tsx"), "utf8"),
    readFile(path.join(root, "app/club-detail-golden.css"), "utf8"),
    readFile(path.join(root, "app/club/[id]/page.tsx"), "utf8"),
    readFile(path.join(root, "app/layout.tsx"), "utf8"),
    readFile(path.join(root, "components/post-detail-route.tsx"), "utf8"),
    readFile(path.join(root, "app/drop/[id]/page.tsx"), "utf8"),
  ]);

  expect(gate).not.toContain("is_developer_account");
  expect(gate).not.toContain("บัญชีนักพัฒนา");
  expect(auth).toContain("<ParityHomeFinal session={session} />");
  expect(auth).not.toContain("HomeMigrationPreview");
  expect(pageSource).not.toContain("HomeNavigationBridge");
  expect(layout).not.toContain("DrawerRouteAdapter");
  for (const sheet of ["home-golden-final.css", "profile-golden-final.css", "club-detail-golden.css", "golden-drop-card.css"]) expect(layout).toContain(sheet);

  for (const label of ["สำหรับคุณ", "กำลังติดตาม", "คลับของฉัน"]) expect(home).toContain(label);
  expect(home).not.toContain("กำลังนิยม");
  expect(home).toContain('/wynos_logo_mark.png');
  for (const label of ["สำรวจ Club", "สร้าง Club", "Club ของฉัน", "บันทึกไว้", "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก"]) expect(home).toContain(label);
  for (const contract of [
    "Quote ReDrop", "ไม่สนใจโพสต์นี้", "เลิกทำ", "submit_report", 'from("feed_signals")',
    "navigator.share", "toggleClubPostLike", "toggleAuthorFollow", "audit-follow-pill", "onShare",
    "row.audience", "ขอติดตามแล้ว", "รีโพสต์โดย @",
  ]) expect(home).toContain(contract);
  expect(home).toContain('<Send size={24} />');
  expect(home).toContain('row.audience == null || row.audience === "everyone"');
  expect(home).not.toContain('location.assign');
  for (const contract of [".audit-follow-pill", "background: var(--ink)", "font-size: 17px", "max-width: 112px", "gap: 16px"]) expect(homeGoldenCss).toContain(contract);

  for (const label of ["หน้าหลัก", "ค้นหา", "การแจ้งเตือน", "โปรไฟล์"]) expect(routeUi).toContain(label);
  expect(routeUi).toContain("โพสต์");
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
  for (const metric of ["height: calc(170px", "width: 92px", "font-size: 21px", "font-size: 20px", "height: 44px", "height: 52px"]) expect(profileGoldenCss).toContain(metric);
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
  expect(settings).toContain("V1.0.0 Beta4");

  for (const label of ["เจอคอมมูนิตี้ที่ใช่", "สำหรับคุณ", "ค้นหา Club", "กำลังนิยม", "ใหม่ล่าสุด", "รออนุมัติ", "Club ของฉัน", "สร้าง Club"]) expect(clubs).toContain(label);
  expect(clubs).not.toContain("Club แนะนำสำหรับคุณ");
  for (const label of ["โพสต์", "แชท", "เกี่ยวกับ", "รายละเอียด", "สมาชิก", "กิจกรรม", "Insights", "รออนุมัติ", "เข้าร่วม"]) expect(clubDetail).toContain(label);
  for (const contract of ['from("club_channels")', 'from("club_channel_messages")', 'from("club_events")', 'rpc("club_insights"']) expect(clubDetail).toContain(contract);
  expect(clubPage).toContain("ClubDetailGoldenRoute");
  for (const label of ["โพสต์", "แชท", "เกี่ยวกับ", "รายละเอียด", "สมาชิก", "กิจกรรม", "Insights", "เข้าร่วม", "รออนุมัติ", "รายงาน Club", "ปิดการแจ้งเตือน Club นี้", "บันทึก", "ปักหมุด"]) expect(clubGolden).toContain(label);
  for (const contract of ["fetchClubPostsForClub", "toggleClubPostSave", "toggleClubPostPin", "voteClubPostPoll", 'from("club_channel_messages")', "mark_club_channel_read", "club_notification_mutes", 'rpc("club_insights"', "submit_report"]) expect(clubGolden).toContain(contract);
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
  for (const contract of ["height: calc(170px", "width: 92px", "height: 44px", "height: 52px", "min-height: 54px", "min-height: 46px"]) expect(completionCss).toContain(contract);
  expect(closureCss).toContain("profile-recommendation-card");
  expect(closureCss).toContain("settings-version-footer");
});
