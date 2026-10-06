import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL("../" + path, import.meta.url), "utf8");

test("Food signed-out users stay in the Food auth flow", async () => {
  const source = await read("components/food/wynos-food-developer-app.tsx");
  assert.match(source, /DeveloperRouteGate signedOutPath="\/food\/login" afterSignOutPath="\/food\/login"/);
  assert.match(source, /onSignOut=\{\(\) => void signOut\(\)\}/);
  assert.match(source, /href="https:\/\/wynos\.online\/login"/);
});

test("Food signup creates only the central auth account", async () => {
  const source = await read("components/food/food-auth.tsx");
  assert.match(source, /signUpWithEmail\(client, normalized, password, "\/food"\)/);
  assert.doesNotMatch(source, /\bsetUsername\s*\(/);
  assert.doesNotMatch(source, /\bsetDisplayName\s*\(/);
  assert.doesNotMatch(source, /\bsetDateOfBirth\s*\(/);
  assert.doesNotMatch(source, /\bcompleteOnboarding\s*\(/);
  assert.doesNotMatch(source, /@wynos_s/);
});

test("email confirmation only honors a safe internal destination", async () => {
  const repository = await read("lib/auth-repository.ts");
  const callback = await read("app/auth/callback/page.tsx");
  assert.match(repository, /getEmailConfirmationRedirectUrl\(nextPath\?: string\)/);
  assert.match(repository, /url\.searchParams\.set\("next", nextPath\)/);
  assert.match(callback, /isSafeReturnPath\(requestedNext\)/);
  assert.match(callback, /: "\/signup\/step-1"/);
});

test("Food auth routes are separate from Social onboarding", async () => {
  const login = await read("app/food/login/page.tsx");
  const signup = await read("app/food/signup/page.tsx");
  assert.match(login, /FoodLoginScreen/);
  assert.match(signup, /FoodSignupScreen/);
  assert.doesNotMatch(login + signup, /signup\/step-1|onboarding\/profile/);
});

test("Food Google login returns to Food without forcing Social onboarding", async () => {
  const foodAuth = await read("components/food/food-auth.tsx");
  const callback = await read("app/auth/callback/page.tsx");

  assert.match(foodAuth, /startGoogleOAuth\(client, callback\.href\)/);
  assert.match(foodAuth, /callback\.searchParams\.set\("next", "\/food"\)/);
  assert.match(foodAuth, /เข้าสู่ระบบด้วย Google/);
  assert.match(foodAuth, /GOOGLE_PWA_COMPLETED_CHANNEL/);
  assert.match(callback, /safeProductDestination/);
  assert.match(callback, /requestedNext && isSafeReturnPath\(requestedNext\)/);
});

test("Food password recovery returns to the Food login flow", async () => {
  const foodAuth = await read("components/food/food-auth.tsx");
  const screens = await read("components/auth-flow/screens.tsx");
  const repository = await read("lib/auth-repository.ts");

  assert.match(foodAuth, /\/forgot-password\?returnTo=%2Ffood%2Flogin/);
  assert.match(screens, /passwordRecoveryReturnPath/);
  assert.match(screens, /resetPasswordForEmail\(supabase, value, returnTo\)/);
  assert.match(screens, /router\.replace\(returnTo\)/);
  assert.match(repository, /\/reset-password\?returnTo=/);
  assert.match(repository, /returnTo: "\/login" \| "\/food\/login"/);
});

test("Food menu card photos stay square at every responsive width", async () => {
  const css = await read("app/food/food.css");
  assert.match(css, /\.wf-menu-image\s*\{[\s\S]*?width:\s*100%;[\s\S]*?height:\s*auto;[\s\S]*?aspect-ratio:\s*1\s*\/\s*1;/);
  assert.doesNotMatch(css, /\.wf-menu-image\s*\{\s*height:\s*(?:120|170)px;/);
});

test("Food Home removes preview UI, promotes Social and hides the back button", async () => {
  const source = await read("components/food/wynos-food-developer-app.tsx");
  const css = await read("app/food/food.css");
  assert.doesNotMatch(source, /<small>Developer Preview<\/small>/);
  assert.doesNotMatch(source, /Developer Preview เท่านั้น/);
  assert.match(source, /className="wf-social-promo" href="https:\/\/wynos\.online\/" aria-label="เปิด WYNOS Social"/);
  assert.match(source, /โพสต์ พูดคุย ติดตาม และค้นหาคอนเทนต์บน wynos\.online/);
  assert.match(source, /tab === "home" && storefrontOpen \? null : \(/);
  assert.match(source, /showBack=\{tab !== "home"\}/);
  assert.match(source, /className="wf-store-back"/);
  assert.match(source, /setStorefrontOpen\(false\)/);
  assert.match(css, /\.wf-header--home\s*\{\s*grid-template-columns:\s*minmax\(0, 1fr\) auto;/);
});

test("Food Public Beta has no user-facing Developer Preview copy", async () => {
  const source = await read("components/food/wynos-food-developer-app.tsx");
  const manifest = await read("app/food/manifest.ts");
  const staticManifest = await read("public/food/manifest.webmanifest");
  assert.doesNotMatch(source, /Developer Preview|ก่อนเริ่มทดสอบฝั่งลูกค้า/);
  assert.match(source, /เพิ่ม WYNOS Food ไว้บนหน้าจอหลัก/);
  assert.match(source, /เพื่อเริ่มขายบน WYNOS Food/);
  assert.match(manifest, /description: "WYNOS Food Public Beta"/);
  assert.match(staticManifest, /"description": "WYNOS Food Public Beta"/);
  assert.doesNotMatch(manifest + staticManifest, /Developer Preview/);
});

test("Food reviews are verified, masked and use yellow five-star UI", async () => {
  const source = await read("components/food/wynos-food-developer-app.tsx");
  const data = await read("lib/food-customer.ts");
  const css = await read("app/food/food.css");
  const migration = await read("../supabase/migrations_wynos_food_store_reviews_v1.sql");
  assert.match(source, /สั่งจริงกับ WYNOS Food/);
  assert.match(source, /อาหารเป็นอย่างไรบ้าง\?/);
  assert.match(source, /FOOD_REVIEW_TAGS/);
  assert.match(source, /submitFoodStoreReview/);
  assert.match(data, /food_store_review_feed/);
  assert.match(data, /food_submit_store_review/);
  assert.match(data, /maskFoodReviewerName/);
  assert.match(css, /\.wf-review-stars[\s\S]*?#f4b400/);
  assert.match(migration, /status <> 'delivered'/);
  assert.match(migration, /internal\.food_mask_reviewer_name/);
  assert.match(migration, /revoke all on table public\.food_store_reviews from public, anon, authenticated/);
  assert.doesNotMatch(migration, /select .*username|avatar_url/i);
});


test("Food Home v2 matches the approved discovery layout and keeps favorite toggles inside stores", async () => {
  const source = await read("components/food/wynos-food-developer-app.tsx");
  const css = await read("app/food/food.css");
  const data = await read("lib/food-customer.ts");
  const migration = await read("../supabase/migrations_wynos_food_home_directory_v2.sql");

  for (const label of [
    "ค้นหาร้านหรือเมนูอาหาร",
    "จัดส่ง",
    "รับเองที่ร้าน",
    "รวมโค้ดลดเพิ่ม",
    "ร้านที่เคยสั่งล่าสุด",
    "ร้านค้าใกล้คุณ",
    "ร้านค้ายอดนิยม",
  ]) assert.match(source, new RegExp(label));

  assert.match(source, /aria-label="ร้านโปรด"/);
  assert.match(source, /wf-store-favorite/);
  const homeRows = source.slice(source.indexOf("function FoodDirectoryStoreRow"), source.indexOf("function FavoriteStoresSheet"));
  assert.doesNotMatch(homeRows, /<Heart\b/);
  assert.doesNotMatch(homeRows, /wf-home-store-logo/);
  assert.doesNotMatch(css, /\.wf-home-store-logo/);
  assert.match(css, /\.wf-home-store-head\s*\{[\s\S]*?grid-template-columns:\s*minmax\(0, 1fr\) 17px;/);

  assert.match(css, /\.wf-home-store-photo\s*\{[\s\S]*?aspect-ratio:\s*1\s*\/\s*1;/);
  assert.match(css, /\.wf-recent-store > span\s*\{[\s\S]*?aspect-ratio:\s*1\s*\/\s*1;/);
  assert.match(source, /distance < 0\.1[\s\S]*?"ใกล้คุณ"/);
  assert.match(source, /<Bike size=\{13\} \/>ค่าส่ง/);
  assert.match(source, /<Bike size=\{15\} \/>จัดส่ง/);
  assert.doesNotMatch(source, /🛵/);
  assert.match(css, /\.wf-home-deals-empty\s*\{[\s\S]*?min-height:\s*42px;/);
  assert.match(css, /\.wf-home-store-row\s*\{[\s\S]*?min-height:\s*116px;/);
  assert.match(css, /\.wf-fulfillment-tabs button\s*\{[\s\S]*?min-height:\s*32px;/);
  assert.match(data, /rating_average\?: number \| string \| null/);
  assert.match(migration, /rating_average numeric/);
  assert.match(migration, /delivered_order_count bigint/);
  assert.match(migration, /promo_name text/);
  assert.match(migration, /search_menu\.name ilike v_pattern/);
  assert.match(migration, /search_menu\.category ilike v_pattern/);
  assert.match(migration, /grant execute on function public\.food_store_directory\(text\) to authenticated/);
});
