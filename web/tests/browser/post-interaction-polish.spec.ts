import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";
import { beginSocialMutation, socialMutationPending } from "../../lib/social-mutation-guard";

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
  expect(read("lib/club-engagement-sync.ts")).toContain("publishClubLike");
  expect(read("components/home/home-screen.tsx")).toContain("listenClubLike(");
  expect(read("components/club-detail-golden.tsx")).toContain("listenClubLike(");
  expect(sync).toContain("post-detail:");
  expect(read("lib/haptics.ts")).toContain("navigator.vibrate");
});

test("like actions stay quiet while failure feedback and save Undo remain", () => {
  const likeSurfaces = [
    "components/home/home-screen.tsx",
    "components/golden-drop-card.tsx",
    "components/post-detail-route.tsx",
    "components/club-detail-golden.tsx",
    "components/quote-feed-card.tsx",
  ];

  for (const file of likeSurfaces) {
    const source = read(file);
    expect(source, file).not.toContain('showToast("ถูกใจโพสต์แล้ว"');
    expect(source, file).not.toContain("const undoLike =");
  }

  const home = read("components/home/home-screen.tsx");
  expect(home).toContain('showToast("ถูกใจไม่สำเร็จ ลองใหม่อีกครั้ง")');
  expect(home).toContain('showToast("บันทึกโพสต์แล้ว", { label: "เลิกทำ"');
  const detail = read("components/post-detail-route.tsx");
  expect(detail).toContain('showToast("อัปเดตกิจกรรมไม่สำเร็จ ลองใหม่อีกครั้ง")');
  expect(detail).toContain('showToast("บันทึกโพสต์แล้ว", { label: "เลิกทำ"');
});

test("fast double taps or simultaneous Feed and Detail mutations cannot race", async () => {
  const user = "reliability-test-user";
  const id = "post-1";
  const finish = beginSocialMutation("drop", user, id, "like");
  expect(finish).not.toBeNull();
  expect(socialMutationPending("drop", user, id, "like")).toBe(true);
  expect(beginSocialMutation("drop", user, id, "like")).toBeNull();
  expect(beginSocialMutation("drop", user, id, "like")).toBeNull();

  // Each action and user has an independent lock; one slow like cannot
  // prevent a separate Save or another account's action.
  const saveFinish = beginSocialMutation("drop", user, id, "save");
  const otherUserFinish = beginSocialMutation("drop", "another-user", id, "like");
  const clubFinish = beginSocialMutation("club", user, id, "like");
  expect(saveFinish).not.toBeNull();
  expect(otherUserFinish).not.toBeNull();
  expect(clubFinish).not.toBeNull();

  finish!();
  finish!(); // release is intentionally idempotent
  expect(socialMutationPending("drop", user, id, "like")).toBe(false);
  const next = beginSocialMutation("drop", user, id, "like");
  expect(next).not.toBeNull();
  next!();
  saveFinish!();
  otherUserFinish!();
  clubFinish!();
});

test("mutation guard is used on all public Drop and Club action surfaces", () => {
  for (const file of [
    "components/home/home-screen.tsx",
    "components/post-detail-route.tsx",
    "components/golden-drop-card.tsx",
    "components/club-detail-golden.tsx",
    "components/quote-feed-card.tsx",
  ]) {
    const source = read(file);
    expect(source, file).toContain('beginSocialMutation(');
    expect(source, file).toContain('definitelyOffline()');
    expect(source, file).toContain('releaseMutation()');
  }
});
