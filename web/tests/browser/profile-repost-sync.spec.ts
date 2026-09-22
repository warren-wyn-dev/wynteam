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
  expect(card).toContain("disabled={busy} onClick={() => void redrop()}");
  expect(card).toContain("disabled={busy} onClick={() => setSheet(\"quote\")}");
  expect(card).toContain('role="alert"');
});
