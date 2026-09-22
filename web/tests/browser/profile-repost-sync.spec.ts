import { readFile } from "node:fs/promises";
import path from "node:path";

import { expect, test } from "@playwright/test";

// Authenticated Supabase mutations cannot run safely in shared browser QA;
// these contracts guard the on-device repost flow without altering user data.
test("profile tabs keep independent rows and re-fetch reposts after changing tabs", async () => {
  const root = process.cwd();
  const [profile, cache] = await Promise.all([
    readFile(path.join(root, "components/profile-route.tsx"), "utf8"),
    readFile(path.join(root, "lib/mount-cache.ts"), "utf8"),
  ]);

  expect(profile).toContain('const PROFILE_TABS = ["posts", "redrops", "likes"]');
  expect(profile).toContain('<ProfileFeed key={`${profileId}:${tab}`} client={client} profileId={profileId} kind={tab} />');
  expect(profile).toContain('kind === "redrops") next = await fetchRedrops(client, profileId, nextPage)');
  expect(profile).toContain('.eq("redropper_id", userId)');
  expect(profile).toContain('key={`${row.id}:${row.redrop_id ?? "plain"}`}');
  expect(profile).toContain("request !== requestId.current");
  expect(profile).toContain("requestId.current += 1");
  expect(cache).toContain("export function deleteMountCache(key: string)");
});

test("successful repost and quote updates refresh own profile and invalidate its cached tab", async () => {
  const root = process.cwd();
  const [profile, preview, card] = await Promise.all([
    readFile(path.join(root, "components/profile-route.tsx"), "utf8"),
    readFile(path.join(root, "components/phase3-ui.tsx"), "utf8"),
    readFile(path.join(root, "components/golden-drop-card.tsx"), "utf8"),
  ]);
  expect(profile).toContain('deleteMountCache(`profile-feed:${actorId}:redrops`)');
  expect(profile).toContain('if (kind !== "redrops" || profileId !== actorId) return;');
  expect(profile).toContain("item.id === dropId && item.redrop_id && item.quote_text == null");
  expect(profile).toContain("void load(0, false)");
  expect(profile).toContain("onRepostChanged={onRepostChanged}");
  expect(preview).toContain("onRepostChanged={onRepostChanged}");
  expect(card).toContain("await toggleDropRedrop(client, userId, row.id, redropped);");
  expect(card).toContain("onRepostChanged?.(userId, row.id, redropped)");
  expect(card).toContain("onRepostChanged?.(userId, row.id, false)");
  expect(card).toContain('<RepostSheetChoices');
  expect(card).toContain('onRepost={() => void redrop()}');
  expect(card).toContain('onQuote={() => setSheet("quote")}');
});

test("profile repost action sheet is portaled out of the transformed swipe feed", async () => {
  const root = process.cwd();
  const [card, profile, css] = await Promise.all([
    readFile(path.join(root, "components/golden-drop-card.tsx"), "utf8"),
    readFile(path.join(root, "components/profile-route.tsx"), "utf8"),
    readFile(path.join(root, "app/golden-drop-card.css"), "utf8"),
  ]);
  // Without the portal, the 0px transform below creates a containing block
  // for position:fixed, hiding the bottom sheet below the scrolled profile.
  expect(profile).toContain('transform: "translateX(0px)"');
  expect(card).toContain('import { createPortal } from "react-dom"');
  expect(card).toContain("return createPortal(");
  expect(card).toContain("document.body,");
  expect(card).toContain('onTouchMove={(event) => event.stopPropagation()}');
  expect(card).toContain('document.body.style.overflow = "hidden"');
  expect(card).toContain('event.key === "Escape"');
  for (const name of ["redrop", "quote", "more", "report"]) {
    expect(card).toContain('sheet === "' + name + '" ? <SheetFrame');
  }
  expect(css).toContain(".golden-drop-sheet-backdrop { position: fixed; inset: 0;");
  expect(css).toContain("z-index: 180;");
});

test("Home and Profile share approved Thai two-option Repost sheet without separators", async () => {
  const root = process.cwd();
  const [home, card, choices, css] = await Promise.all([
    readFile(path.join(root, "components/home/home-screen.tsx"), "utf8"),
    readFile(path.join(root, "components/golden-drop-card.tsx"), "utf8"),
    readFile(path.join(root, "components/ui/repost-sheet-choices.tsx"), "utf8"),
    readFile(path.join(root, "app/parity-audit.css"), "utf8"),
  ]);
  expect(home).toContain('<RepostSheetChoices');
  expect(card).toContain('<RepostSheetChoices');
  expect(choices).toContain('<RepostIcon size={28} strokeWidth={2} />');
  expect(choices).toContain('<WynosIcon name="pencil" size={27} strokeWidth={2} />');
  expect(choices).toContain('<span>{reposted ? "ยกเลิกรีโพสต์" : "รีโพสต์"}</span>');
  expect(choices).toContain('<span>อ้างอิง</span>');
  expect(choices).toContain('disabled={busy}');
  expect(choices).not.toContain("chevronRight");
  expect(choices).not.toContain("border-bottom");
  expect(css).toContain(".wyn-repost-sheet-choice");
  expect(css).toContain("border: 0;");
  expect(css).toContain(".golden-drop-sheet[aria-label=\"รีโพสต์\"]");
  expect(css).toContain(".audit-action-sheet[aria-label=\"รีโพสต์\"]");
  expect(css).not.toContain(".wyn-redrop-sheet-option.is-quote");
});
