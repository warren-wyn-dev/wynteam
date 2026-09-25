import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("cold-start INITIAL_SESSION null plus a transient auth error must offer retry, not redirect", async ({ page }) => {
  await page.goto("/dev/auth-reopen-fixture", { waitUntil: "networkidle" });
  await expect(page.getByRole("alert")).toContainText("ตรวจสอบการเข้าสู่ระบบไม่สำเร็จ");
  await expect(page).toHaveURL(/\/dev\/auth-reopen-fixture/);
  await expect(page.getByRole("button", { name: "ลองใหม่" })).toBeVisible();
  await page.getByRole("button", { name: "Read session-check count" }).click();
  const before = Number(await page.getByLabel("session checks").textContent());
  await page.getByRole("button", { name: "ลองใหม่" }).click();
  await expect(page.getByRole("alert")).toBeVisible();
  await page.getByRole("button", { name: "Read session-check count" }).click();
  const after = Number(await page.getByLabel("session checks").textContent());
  expect(after).toBeGreaterThan(before);
  await expect(page).toHaveURL(/\/dev\/auth-reopen-fixture/);
});

test("an actual SIGNED_OUT event still immediately navigates to Welcome", async ({ page }) => {
  await page.goto("/dev/auth-reopen-fixture", { waitUntil: "networkidle" });
  await expect(page.getByRole("alert")).toBeVisible();
  await page.getByRole("button", { name: "Simulate explicit sign out" }).click();
  await expect(page).toHaveURL(/\/welcome/);
});

test("Home, route gates and Welcome distinguish an auth read failure from sign-out", () => {
  const source = (file: string) => readFileSync(path.join(process.cwd(), file), "utf8");
  const home = source("components/parity-auth-entry.tsx");
  const routes = source("components/developer-route-gate.tsx");
  const welcome = source("components/auth-flow/screens.tsx");
  const browser = source("lib/supabase/browser.ts");
  expect(home).toContain('event === "INITIAL_SESSION"');
  expect(home).toContain('if (error)');
  expect(home).toContain(".catch(onCheckError)");
  expect(home).toContain('role="alert"');
  expect(routes).toContain('event === "INITIAL_SESSION"');
  expect(routes).toContain(".catch(onCheckError)");
  expect(welcome).toContain("setSessionCheckFailed(true)");
  expect(browser).toContain("persistSession: true");
  expect(browser).toContain("autoRefreshToken: true");
});
