import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
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

test("Food Google login uses a dedicated exact callback and never falls into Social", async () => {
  const foodAuth = await read("components/food/food-auth.tsx");
  const foodCallback = await read("app/food/auth/callback/page.tsx");
  const sharedCallback = await read("app/auth/callback/page.tsx");

  assert.match(foodAuth, /foodAuthOriginFor\(window\.location\.hostname, window\.location\.origin\)/);
  assert.match(foodAuth, /redirectFoodAuthToCanonicalOrigin\("\/food\/login"\)/);
  assert.match(foodAuth, /new URL\("\/food\/auth\/callback", canonicalOrigin\)/);
  assert.doesNotMatch(foodAuth, /callback\.searchParams\.set\("next", "\/food"\)/);
  assert.match(foodAuth, /startGoogleOAuth\(client, callback\.href\)/);
  assert.match(foodAuth, /window\.location\.origin !== canonicalOrigin/);
  assert.match(foodAuth, /isLegacyInstalledFoodOrigin\(\)/);
  assert.match(foodAuth, /เปิด ZOKY ที่ zoky\.wynos\.online/);
  assert.match(foodAuth, /เข้าสู่ระบบด้วย Google/);
  assert.match(foodAuth, /GOOGLE_PWA_COMPLETED_CHANNEL/);

  assert.match(foodCallback, /registerCurrentAccount/);
  assert.match(foodCallback, /consumeGooglePwaPopupMarker/);
  assert.match(foodCallback, /window\.location\.replace\(foodHomeUrl\(\)\)/);
  assert.doesNotMatch(foodCallback, /signup\/step-1/);

  assert.match(sharedCallback, /legacyFoodReturn = requestedNext === "\/food"/);
  // ZOKY-139: return to the Food origin this callback runs on, not a hardcoded ZOKY origin.
  assert.match(sharedCallback, /window\.location\.replace\(foodHome\(\)\)/);
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
  const css = await read("app/food/food-app.css");
  assert.doesNotMatch(source, /<small>Developer Preview<\/small>/);
  assert.doesNotMatch(source, /Developer Preview เท่านั้น/);
  assert.match(source, /className="fx-social-promo" href="https:\/\/wynos\.online\/" aria-label="เปิด WYNOS Social"/);
  assert.match(source, /โพสต์ พูดคุย ติดตาม และค้นหาคอนเทนต์บน wynos\.online/);
  // ZOKY web (2026-10-19): Home and Food discovery only while no storefront is open;
  // inner pages use FoodPageHeader with a back button.
  assert.match(source, /const discovery = tab === "home" && !storefrontOpen \? \(/);
  assert.match(source, /<ZokyHomeHeader/);
  assert.match(source, /aria-label="กลับหน้าหลัก ZOKY" onClick=\{onBackStorefront\}/);
  assert.match(source, /setStorefrontOpen\(false\)/);
  assert.match(css, /\.zk-home-header\s*\{/);
});

test("Food Public Beta has no user-facing Developer Preview copy", async () => {
  const source = await read("components/food/wynos-food-developer-app.tsx");
  const manifest = await read("app/food/manifest.ts");
  const staticManifest = await read("public/food/manifest.webmanifest");
  assert.doesNotMatch(source, /Developer Preview|ก่อนเริ่มทดสอบฝั่งลูกค้า/);
  assert.match(source, /เพิ่ม ZOKY ไว้บนหน้าจอหลัก/);
  assert.match(source, /เพื่อเริ่มขายบน ZOKY/);
  assert.match(manifest, /description: "ZOKY สั่งอาหาร \(Public Beta\)"/);
  assert.match(staticManifest, /"description": "ZOKY สั่งอาหาร \(Public Beta\)"/);
  assert.doesNotMatch(manifest + staticManifest, /Developer Preview/);
});

test("Food reviews are verified, masked and use yellow five-star UI", async () => {
  const source = await read("components/food/wynos-food-developer-app.tsx");
  const data = await read("lib/food-customer.ts");
  const css = await read("app/food/food.css");
  const migration = await read("../supabase/migrations_wynos_food_store_reviews_v1.sql");
  assert.match(source, /สั่งจริงกับ ZOKY/);
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
  const css = await read("app/food/food-app.css");
  const data = await read("lib/food-customer.ts");
  const migration = await read("../supabase/migrations_wynos_food_home_directory_v2.sql");

  // ZOKY web Home + Food (2026-10-19): the nearby list became "ร้านอาหารทั้งหมด" (open first, then nearest).
  for (const label of [
    "ค้นหาร้านอาหารหรือเมนู",
    "รวมโค้ดลดเพิ่ม",
    "โค้ดลดเพิ่มสำหรับคุณ",
    "สั่งอีกครั้ง",
    "ร้านอาหารทั้งหมด",
    "ร้านยอดนิยม",
  ]) assert.match(source, new RegExp(label));
  // Founder 2026-10-26: same-day pickup; delivery remains immediate.
  assert.match(source, /รับเองที่ร้าน/);
  assert.match(source, /pickupSlots\.includes\(pickupAt\)/);
  assert.doesNotMatch(source, /useState<"asap" \| "scheduled">/);
  assert.match(source, /scheduledFor: null/);

  assert.match(source, /label="ร้านโปรด"/);
  assert.match(source, /aria-label="รายการโปรด"\s*aria-pressed=\{favorite\}/);
  const homeRows = source.slice(source.indexOf("function FoodStoreRow"), source.indexOf("function FoodRecentStoreTile"));
  assert.ok(homeRows.length > 0);
  assert.doesNotMatch(homeRows, /<Heart\b/);

  // Store photos are 1:1 (Founder rule) in the Food rows and the Home popular cards.
  assert.match(css, /\.zk-store-row-photo \{[^}]*aspect-ratio: 1;/);
  assert.match(css, /\.zk-pop-card-photo \{[^}]*aspect-ratio: 1;/);
  // Ratings only with real reviews; ETA only with real preparation times.
  assert.match(source, /return rating > 0 && count > 0 \? rating : null;/);
  assert.match(source, /if \(store\.prep_time_min_minutes == null \|\| store\.prep_time_max_minutes == null\) return null;/);
  assert.match(source, /distance < 0\.1\) return "ใกล้คุณ"/);
  assert.doesNotMatch(source, /🛵/);
  assert.match(data, /rating_average\?: number \| string \| null/);
  assert.match(migration, /rating_average numeric/);
  assert.match(migration, /delivered_order_count bigint/);
  assert.match(migration, /promo_name text/);
  assert.match(migration, /search_menu\.name ilike v_pattern/);
  assert.match(migration, /search_menu\.category ilike v_pattern/);
  assert.match(migration, /grant execute on function public\.food_store_directory\(text\) to authenticated/);
});

test("Food framed photos fill their frame on iOS Safari (absolute fill, not grid-centered height:100%)", async () => {
  const css = await read("app/food/food-app.css");
  for (const frame of [".fx-store-cover", ".fx-store-card-photo", ".zk-store-row-photo", ".zk-pop-card-photo", ".fx-menu-image", ".fx-item-photo", ".fx-recent-store", ".fx-cart-store-logo"]) {
    const escaped = frame.replace(/[.]/g, "\\.");
    assert.match(css, new RegExp(`${escaped} img \\{ position: absolute; inset: 0; width: 100%; height: 100%;`), `${frame} img must be absolutely filled`);
  }
});

test("Food launch splash shows the brand once per session without hydration mismatch", async () => {
  const layout = await read("app/food/layout.tsx");
  const css = await read("app/food/food-app.css");
  assert.match(layout, /className="fx-splash" aria-hidden="true"/);
  assert.match(layout, /sessionStorage\.getItem\('wynos-food-splash'\)/);
  // Blocked storage must not stop the ready hook and timer from being set up.
  assert.match(layout, /try\{seen=sessionStorage\.getItem\('wynos-food-splash'\)\}catch\(e\)\{\}/);
  assert.match(layout, /try\{sessionStorage\.setItem\('wynos-food-splash','1'\)\}catch\(e\)\{\}/);
  // Only <html> (suppressHydrationWarning in the root layout) is touched before hydration.
  assert.match(layout, /d\.setAttribute\('data-fx-splash','seen'\)/);
  assert.match(css, /html\[data-fx-splash="seen"\] \.fx-splash \{ display: none; \}/);
  assert.match(css, /@keyframes fx-splash-out \{ to \{ opacity: 0; visibility: hidden; \} \}/);
});

test("Food iOS launch has no white flash and the status bar matches the splash", async () => {
  const layout = await read("app/food/layout.tsx");
  // iOS ignores the manifest background; it needs apple-touch-startup-image per screen size.
  assert.match(layout, /startupImage: FOOD_IOS_LAUNCH_IMAGES/);
  assert.match(layout, /\/icons\/zoky\/splash\/launch-\$\{width \* ratio\}x\$\{height \* ratio\}\.png\?v=\$\{FOOD_IOS_LAUNCH_VERSION\}/);
  assert.match(layout, /const FOOD_IOS_LAUNCH_VERSION = 1;/);
  for (const size of ["1290x2796", "1179x2556", "1170x2532", "1080x2340", "750x1334", "2048x2732", "1668x2388", "1640x2360", "1620x2160", "1488x2266"]) {
    assert.ok(existsSync(new URL(`../public/icons/zoky/splash/launch-${size}.png`, import.meta.url)), `missing launch image ${size}`);
  }
  // Temporary pink theme-color while the splash shows, switched off when it fades.
  assert.match(layout, /m\.content='#f93384'/);
  // iOS 26 colours the status bar from the fixed splash's background-color, so it must be the top pink.
  assert.match(await read("app/food/food-app.css"), /background-color: #f93384;/);
  assert.match(layout, /\[360, 780, 3\]/); // iPhone 12/13 mini
  assert.match(layout, /\[1024, 1366, 2\], \[834, 1194, 2\], \[820, 1180, 2\], \[810, 1080, 2\], \[744, 1133, 2\]/); // iPad
  assert.match(layout, /document\.head\.prepend\(m\)/);
  // Theme sync must not repaint the splash's temporary status-bar color.
  assert.match(await read("lib/theme-preference.ts"), /meta\[name="theme-color"\]:not\(\[data-fx-splash-theme\]\)/);
  // ZOKY-145: switch the meta off instead of removing it; removing a <head> node React owns
  // crashes the next client navigation (guest → /food/login showed a dead page).
  assert.match(layout, /d\.setAttribute\('data-fx-splash-ready',''\);setTimeout\(function\(\)\{m\.removeAttribute\('name'\)\},350\)/);
  assert.doesNotMatch(layout, /m\.remove\(\)/);
});

test("Food splash stays until the screen has data (min 1 s, max ~4 s)", async () => {
  const layout = await read("app/food/layout.tsx");
  const css = await read("app/food/food-app.css");
  const helper = await read("lib/food-splash.ts");
  assert.match(layout, /Math\.max\(0,1000-\(Date\.now\(\)-t\)\)/);
  assert.match(layout, /setTimeout\(window\.__fxSplashReady,4000\)/);
  assert.match(css, /animation: fx-splash-out \.35s ease 4\.4s forwards;/);
  assert.match(css, /html\[data-fx-splash-ready\] \.fx-splash \{ animation: fx-splash-ready \.35s ease forwards; \}/);
  assert.match(css, /@keyframes fx-splash-ready \{ to \{ opacity: 0; visibility: hidden; \} \}/);
  assert.match(helper, /__fxSplashReady\?\.\(\)/);
  const app = await read("components/food/wynos-food-developer-app.tsx");
  assert.match(app, /if \(snapshot \|\| loadError\) markFoodSplashReady\(\)/);
  assert.match(await read("components/food/food-guest-browse.tsx"), /if \(stores !== null\) markFoodSplashReady\(\)/);
  assert.equal((await read("components/food/food-auth.tsx")).match(/if \(!checking\) markFoodSplashReady\(\)/g)?.length, 2);
});

test("Supabase browser clients retry a just-issued session the database sees as from the future", async () => {
  // Never show the raw English PostgREST message to customers or merchants.
  for (const file of ["lib/food-customer.ts", "lib/food-merchant.ts"]) {
    assert.match(await read(file), /const sessionCopy = sessionErrorCopy\(message\);\n  if \(sessionCopy\) return sessionCopy;/, file);
  }
  for (const file of ["lib/supabase/browser.ts", "lib/supabase/merchant-browser.ts"]) {
    assert.match(await read(file), /global: \{ fetch: createClockSkewRetryFetch\(\) \}/, file);
  }
});
