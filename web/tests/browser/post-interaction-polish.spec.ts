import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const read = (file: string) => readFileSync(path.join(process.cwd(), file), "utf8");

test("bookmark keeps the approved artwork and an undoable save toast", async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const post = page.locator(".wyn-post").first();
  const save = post.getByRole("button", { name: "บันทึก", exact: true });
  await expect(save).toHaveAttribute("aria-pressed", "false");
  await expect(save.locator("svg")).toHaveAttribute("fill", "none");

  await save.click();
  const unsave = post.getByRole("button", { name: "ยกเลิกบันทึก", exact: true });
  await expect(unsave).toHaveAttribute("aria-pressed", "true");
  await expect(unsave.locator("svg")).toHaveAttribute("fill", "currentColor");
  const toast = page.getByRole("status").filter({ hasText: "บันทึกโพสต์แล้ว" });
  await expect(toast).toBeVisible();
  await toast.getByRole("button", { name: "เลิกทำ" }).click();
  await expect(post.getByRole("button", { name: "บันทึก", exact: true })).toHaveAttribute("aria-pressed", "false");
});

test("post press feedback and reduced-motion fallback are scoped to post controls", () => {
  const css = read("app/post-interaction-polish.css");
  const layout = read("app/layout.tsx");
  const bookmark = read("components/ui/animated-bookmark.tsx");
  expect(layout).toContain('import "./post-interaction-polish.css";');
  expect(css).toContain("transform: scale(0.94)");
  expect(css).toContain(".wyn-post-actions .wyn-action-button:active:not(:disabled)");
  expect(css).toContain("@media (prefers-reduced-motion: reduce)");
  expect(bookmark).toContain("useReducedMotion()");
  expect(bookmark).toContain('<SaveIcon saved={saved}');
});

test("home, detail and profile publish and receive session-local engagement changes", () => {
  const sync = read("lib/drop-engagement-sync.ts");
  for (const file of ["components/home/home-screen.tsx", "components/post-detail-route.tsx", "components/golden-drop-card.tsx"]) {
    const code = read(file);
    expect(code).toContain("publishDropEngagement(");
    expect(code).toContain("listenDropEngagement(");
    expect(code).toContain("getRecentDropEngagement(");
  }
  expect(sync).toContain('if (change.kind === "save") deleteMountCache');
  expect(sync).toContain("post-detail:");
  expect(read("lib/haptics.ts")).toContain("navigator.vibrate");
});
