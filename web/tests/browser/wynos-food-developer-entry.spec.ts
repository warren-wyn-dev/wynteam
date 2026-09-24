import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const source = (path: string) => readFileSync(join(process.cwd(), path), "utf8");

test("Food shortcut is rendered only on a confirmed developer's For You feed", () => {
  const home = source("components/home/home-screen.tsx");
  expect(home).toContain("useIsDeveloperAccount(client, userId)");
  expect(home).toContain('isDeveloper && visibleMode === "for-you" ? <WynosFoodEntry /> : null');
  const gate = source("lib/use-is-developer-account.ts");
  expect(gate).toContain("result?.userId === userId");
  expect(home).not.toContain("window.location.assign(\"https://food.wynos.online");
});

test("Food preview checks the developer RPC again and fails closed", () => {
  const preview = source("components/food/wynos-food-preview-route.tsx");
  expect(preview).toContain('client.rpc("is_developer_account")');
  expect(preview).toContain('!error && data === true ? "allowed" : "denied"');
  expect(preview).toContain('if (live) setAccess("denied")');
  expect(preview).toContain('if (access === "denied") router.replace("/")');
  expect(preview).toContain('if (access !== "allowed")');
  expect(preview).toContain("<FoodDemoApp />");
  const demo = source("components/food/food-demo-app.tsx");
  expect(demo).toContain("ยังไม่รับออเดอร์จริง");
});

test("Food shortcut does not change the five existing bottom nav destinations", () => {
  const home = source("components/home/home-screen.tsx");
  const entry = source("components/home/wynos-food-entry.tsx");
  expect(home).toContain("showBottomNav");
  expect(entry).toContain('href="/food"');
  expect(entry).not.toContain("bottom-nav");
});
