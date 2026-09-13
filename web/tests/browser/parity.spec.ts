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
    return { titleSize: getComputedStyle(title).fontSize, titleWeight: getComputedStyle(title).fontWeight, ctaHeight: cta.getBoundingClientRect().height };
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

test("source contracts cannot regress to the staged migration UI", async () => {
  const root = process.cwd();
  const [gate, auth, home, pageSource, routeUi, finalCss, completionCss, closureCss, search, profile, chat, notifications, settings, drawerRoutes] = await Promise.all([
    readFile(path.join(root, "components/developer-route-gate.tsx"), "utf8"),
    readFile(path.join(root, "components/parity-auth-entry.tsx"), "utf8"),
    readFile(path.join(root, "components/parity-home.tsx"), "utf8"),
    readFile(path.join(root, "app/page.tsx"), "utf8"),
    readFile(path.join(root, "components/phase3-ui.tsx"), "utf8"),
    readFile(path.join(root, "app/parity-final.css"), "utf8"),
    readFile(path.join(root, "app/parity-completion.css"), "utf8"),
    readFile(path.join(root, "app/parity-closure.css"), "utf8"),
    readFile(path.join(root, "components/search-route.tsx"), "utf8"),
    readFile(path.join(root, "components/profile-route.tsx"), "utf8"),
    readFile(path.join(root, "components/chat-routes.tsx"), "utf8"),
    readFile(path.join(root, "components/notifications-route.tsx"), "utf8"),
    readFile(path.join(root, "components/settings-route.tsx"), "utf8"),
    readFile(path.join(root, "components/drawer-route-adapter.tsx"), "utf8"),
  ]);

  expect(gate).not.toContain("is_developer_account");
  expect(gate).not.toContain("บัญชีนักพัฒนา");
  expect(auth).toContain("<ParityHome session={session} />");
  expect(auth).not.toContain("HomeMigrationPreview");
  expect(pageSource).not.toContain("HomeNavigationBridge");

  for (const label of ["สำหรับคุณ", "กำลังติดตาม", "คลับของฉัน"]) expect(home).toContain(label);
  expect(home).not.toContain("กำลังนิยม");
  expect(home).toContain('/wynos_logo_mark.png');

  for (const label of ["หน้าหลัก", "ค้นหา", "การแจ้งเตือน", "โปรไฟล์"]) expect(routeUi).toContain(label);
  expect(routeUi).toContain("โพสต์");

  expect(search).toContain('headerMode="hidden"');
  expect(search).toContain("แฮชแท็กกำลังนิยม");
  expect(search).toContain("แนะนำให้ติดตาม");
  expect(search).not.toContain("กำลังเติบโต");
  for (const label of ["User", "โพสต์", "Club"]) expect(search).toContain(label);

  for (const label of ["สื่อ", "รีโพสต์", "ถูกใจ", "แก้ไขโปรไฟล์", "ส่งข้อความ"]) expect(profile).toContain(label);
  expect(profile).toContain("ProfileRecommendations");
  expect(profile).toContain('headerMode="hidden"');

  expect(chat).toContain("ทั้งหมด");
  expect(chat).toContain("ยังไม่อ่าน");
  expect(chat).toContain("คำขอข้อความ");
  expect(chat).not.toContain('setRequestMode');

  expect(notifications).toContain("ทั้งหมด");
  expect(notifications).toContain("การกล่าวถึง");
  expect(notifications).toContain("markAllNotificationsRead");

  for (const label of ["บัญชี", "ความเป็นส่วนตัว", "การตั้งค่าแอป", "การแจ้งเตือน", "ธีมเข้ม", "ช่วยเหลือ", "ข้อกำหนดและความเป็นส่วนตัว", "ออกจากระบบ"]) expect(settings).toContain(label);
  expect(settings).toContain("V1.0.0 Beta4");

  for (const [label, href] of [["สำรวจ Club", "/clubs"], ["สร้าง Club", "/clubs/new"], ["Club ของฉัน", "/clubs?mine=1"], ["บันทึกไว้", "/bookmarks"]]) {
    expect(drawerRoutes).toContain(`\"${label}\": \"${href}\"`);
  }

  for (const metric of [
    "--wyn-social-header: 60px",
    "--wyn-social-tab: 52px",
    "--wyn-social-search: 44px",
    "--wyn-profile-cover: 170px",
    "--wyn-profile-action: 44px",
    "--wyn-detail-media-radius: 18px",
    "--wyn-detail-activity: 54px",
    "--wyn-comment-composer: 46px",
  ]) expect(finalCss).toContain(metric);

  for (const contract of ["height: calc(170px", "width: 92px", "height: 44px", "height: 52px", "min-height: 54px", "min-height: 46px"]) expect(completionCss).toContain(contract);
  expect(closureCss).toContain("profile-recommendation-card");
  expect(closureCss).toContain("settings-version-footer");
});
