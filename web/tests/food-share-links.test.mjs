// WYNOS Food store share links: food.wynos.online/?store=<id> opens that store,
// survives the sign-in wall once, and never trusts a malformed id.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const STORE = "3f2b8c1a-9d4e-4a6b-8c2d-1e5f7a9b0c3d";

function load(now = () => 1_000_000) {
  const store = new Map();
  const window = { sessionStorage: {
    getItem: (k) => store.get(k) ?? null, setItem: (k, v) => store.set(k, String(v)), removeItem: (k) => store.delete(k),
  } };
  const out = ts.transpileModule(read("../lib/food-share.ts"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const mod = { exports: {} };
  runInNewContext(out, { module: mod, exports: mod.exports, window, JSON, URLSearchParams, encodeURIComponent, Boolean, Date: { now } });
  return { ...mod.exports, store };
}

test("share link points at the Food domain with the store id", () => {
  const { foodStoreShareUrl, foodStoreShareData } = load();
  assert.equal(foodStoreShareUrl(STORE), `https://food.wynos.online/?store=${STORE}`);
  const data = foodStoreShareData({ id: STORE, name: "ข้าวมันไก่ป้าแดง" });
  assert.equal(data.url, `https://food.wynos.online/?store=${STORE}`);
  assert.match(data.text, /ข้าวมันไก่ป้าแดง/);
  assert.match(data.title, /WYNOS Food/);
});

test("only a well-formed store id is read from the link", () => {
  const { sharedFoodStoreId } = load();
  assert.equal(sharedFoodStoreId(`?store=${STORE}`), STORE);
  assert.equal(sharedFoodStoreId(`?store=%20${STORE}%20`), STORE);
  for (const bad of ["", "?store=", "?store=abc", `?store=${STORE}x`, "?store=../admin", "?store=<script>"]) {
    assert.equal(sharedFoodStoreId(bad), null, bad);
  }
});

test("a shared store is kept across sign-in and expires", () => {
  let clock = 1_000_000;
  const s = load(() => clock);
  s.rememberSharedFoodStore(STORE);
  assert.equal(s.pendingSharedFoodStore(), STORE);
  s.clearSharedFoodStore();
  assert.equal(s.pendingSharedFoodStore(), null, "cleared once opened");
  s.rememberSharedFoodStore("not-a-store");
  assert.equal(s.pendingSharedFoodStore(), null);
  s.rememberSharedFoodStore(STORE);
  clock += 61 * 60 * 1000;
  assert.equal(s.pendingSharedFoodStore(), null, "expired after an hour");
  s.store.set("wynos-food-shared-store-v1", JSON.stringify({ storeId: "x", at: clock }));
  assert.equal(s.pendingSharedFoodStore(), null, "tampered storage is rejected");
});

test("Food and Merchant are wired to the share link", () => {
  const food = read("../components/food/wynos-food-developer-app.tsx");
  const merchant = read("../components/merchant/wynos-merchant-app.tsx");
  // Remembered before the sign-in redirect (layout effect) and opened after it.
  assert.match(food, /useLayoutEffect\(\(\) => \{\s*const shared = sharedFoodStoreId\(window\.location\.search\);\s*if \(shared\) rememberSharedFoodStore\(shared\);/);
  assert.match(food, /sharedFoodStoreId\(window\.location\.search\) \?\? pendingSharedFoodStore\(\)/);
  assert.match(food, /clearSharedFoodStore\(\);/);
  assert.match(food, /shareOrCopyLink\(foodStoreShareData\(store\), setMessage\)/);
  // Merchants can share only a store customers can actually see.
  assert.match(merchant, /store\.is_published && !store\.admin_suspended_at \? \([\s\S]*?shareOrCopyLink\(foodStoreShareData\(store\), onMessage\)/);
});

test("link preview uses the store's name, description and cover from the public bucket", () => {
  const { foodStorePreviewContent, foodPublicFileUrl } = load();
  const base = { id: STORE, name: "มะละป๊อกป๊อก", description: null, logo_path: null, cover_path: null };
  const supa = "https://abc.supabase.co/";
  assert.equal(foodPublicFileUrl(supa, "stores/a b/cover.jpg"), "https://abc.supabase.co/storage/v1/object/public/food-public/stores/a%20b/cover.jpg");
  const withCover = foodStorePreviewContent({ ...base, description: "ส้มตำ", logo_path: "l.png", cover_path: "c.jpg" }, supa);
  assert.equal(withCover.title, "มะละป๊อกป๊อก | WYNOS Food");
  assert.equal(withCover.description, "ส้มตำ");
  assert.match(withCover.imageUrl, /food-public\/c\.jpg$/);
  assert.equal(withCover.largeImage, true);
  const logoOnly = foodStorePreviewContent({ ...base, logo_path: "l.png" }, supa);
  assert.match(logoOnly.imageUrl, /food-public\/l\.png$/);
  assert.equal(logoOnly.largeImage, false);
  assert.match(logoOnly.description, /มะละป๊อกป๊อก/);
  assert.equal(foodStorePreviewContent(base, supa).imageUrl, null);
});

test("share preview reads only the public RPC with the publishable key", () => {
  const preview = read("../lib/food-share-preview.ts");
  const page = read("../app/food/page.tsx");
  const sql = readFileSync(new URL("../../supabase/migrations_wynos_food_share_preview_v1.sql", import.meta.url), "utf8");
  assert.match(page, /generateMetadata[\s\S]*foodStoreShareMetadata\(store\)\) \?\? \{\}/);
  assert.match(preview, /rest\/v1\/rpc\/food_store_share_preview/);
  assert.match(preview, /NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY/);
  assert.doesNotMatch(preview, /SERVICE_ROLE/i);
  assert.match(preview, /if \(!isFoodStoreId\(storeId\)\) return null;/);
  // Published, non-suspended stores only; no contact or payment columns.
  assert.match(sql, /s\.is_published\s+and s\.admin_suspended_at is null/);
  assert.doesNotMatch(sql.replace(/^--.*$/gm, ""), /phone|address|promptpay|bank|owner/i);
  assert.match(sql, /grant execute on function public\.food_store_share_preview\(uuid\) to anon, authenticated;/);
});
