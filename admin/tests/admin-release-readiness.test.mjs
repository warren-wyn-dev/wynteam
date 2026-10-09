import assert from "node:assert/strict";
import { test } from "node:test";
import { spawnSync } from "node:child_process";
import { readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import { validateAdminBackend } from "../scripts/check-admin-environment.mjs";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const production = "https://kqokpocajhfbidcxpvhh.supabase.co";
const staging = "https://yydgdapzlrjmlrjgijkj.supabase.co";
const stripeSandbox = "https://pcatuxtenluqzjzzwsvl.supabase.co";

test("Production backend preflight allows only WYNOS Production", () => {
  assert.equal(validateAdminBackend({ target: "production", url: production }).target, "production");
  for (const url of [staging, stripeSandbox, "http://127.0.0.1:54321", "https://evil.example.com", ""]) {
    assert.throws(() => validateAdminBackend({ target: "production", url }), /backend|HTTPS|URL/);
  }
});

test("Preview backend preflight fails closed without dedicated staging configuration", () => {
  assert.throws(() => validateAdminBackend({ target: "preview", url: staging }), /ADMIN_PREVIEW_SUPABASE_PROJECT_REF/);
  assert.throws(() => validateAdminBackend({ target: "preview", url: stripeSandbox, previewRef: "pcatuxtenluqzjzzwsvl" }), /Stripe Sandbox/);
  assert.throws(() => validateAdminBackend({ target: "preview", url: production, previewRef: "kqokpocajhfbidcxpvhh" }), /Production/);
  assert.throws(() => validateAdminBackend({ target: "preview", url: production, previewRef: "yydgdapzlrjmlrjgijkj" }), /does not match/);
  assert.equal(validateAdminBackend({ target: "preview", url: staging, previewRef: "yydgdapzlrjmlrjgijkj" }).target, "preview");
  assert.throws(() => validateAdminBackend({ target: "preview", url: "https://yydgdapzlrjmlrjgijkj.supabase.co.evil.com", previewRef: "yydgdapzlrjmlrjgijkj" }), /Supabase project URL/);
  assert.throws(() => validateAdminBackend({ target: "staging", url: staging }), /target/);
});

test("Login treats backend/schema errors differently from unauthorized roles and signs out", () => {
  const login = read("../app/login/actions.ts");
  assert.match(login, /const \{ data: profile, error: profileError \}/);
  assert.match(login, /profileError && profileError\.code !== "PGRST116"/);
  assert.match(login, /ระบบตรวจสอบสิทธิ์ไม่พร้อมใช้งาน/);
  assert.match(login, /await supabase\.auth\.signOut\(\)/);
  assert.match(login, /บัญชีนี้ไม่มีสิทธิ์/);
  assert.match(login, /redirect\("\/"\)/);
});

test("Every Admin workspace route has a corresponding page and is behind the server role gate", () => {
  const root = dirname(fileURLToPath(import.meta.url));
  const adminPagesRoot = join(root, "../app/(admin)");
  const nav = read("../lib/admin-nav.ts");
  const urls = [...nav.matchAll(/\{ href: "(\/[^"]*)", label:/g)].map((match) => match[1]);
  assert.ok(urls.length >= 15, "all functional workspace entries remain visible in the registry");
  assert.equal(new Set(urls).size, urls.length, "menu routes are not duplicated");
  for (const url of urls) {
    const filepath = join(adminPagesRoot, url === "/" ? "page.tsx" : url.slice(1) + "/page.tsx");
    assert.ok(statSync(filepath).isFile(), url + " needs an Admin page");
  }

  const layout = read("../app/(admin)/layout.tsx");
  const requireRole = read("../lib/auth.ts");
  assert.match(layout, /await requireAdminRole\(\)/);
  assert.match(requireRole, /supabase\.auth\.getUser\(\)/);
  assert.match(requireRole, /\.select\("platform_role"\)/);
  assert.match(requireRole, /role !== "admin" && role !== "moderator"/);
  assert.match(requireRole, /redirect\("\/login"\)/);
  const orders = read("../app/(admin)/food/orders/page.tsx");
  const ads = read("../app/(admin)/food/ads/page.tsx");
  assert.match(orders, /role !== "admin"/);
  assert.match(ads, /role !== "admin"/);
});

test("Admin route tree has loading and retry UI and login field labels", () => {
  const login = read("../app/login/login-form.tsx");
  const error = read("../app/(admin)/error.tsx");
  const loading = read("../app/(admin)/loading.tsx");
  const menu = read("../components/admin/sidebar.tsx");
  assert.match(login, /htmlFor="email"/);
  assert.match(login, /htmlFor="password"/);
  assert.match(login, /role="alert"/);
  assert.match(login, /aria-busy=\{isPending\}/);
  assert.match(error, /onClick=\{reset\}/);
  assert.match(loading, /role="status"/);
  assert.match(menu, /aria-current=\{active \? "page"/);
  assert.match(menu, /safe-area-inset-bottom/);
});

test("Admin deploy workflow uses separate Staging secrets and validates target before deploying", () => {
  const wf = read("../../.github/workflows/deploy-admin.yml");
  assert.match(wf, /ADMIN_STAGING_SUPABASE_URL/);
  assert.match(wf, /ADMIN_STAGING_SUPABASE_PUBLISHABLE_KEY/);
  assert.match(wf, /ADMIN_PREVIEW_SUPABASE_PROJECT_REF/);
  assert.match(wf, /check-admin-environment\.mjs/);
  assert.match(wf, /DEPLOY_ADMIN_PRODUCTION/);
  assert.doesNotMatch(wf, /--token=/);
});

test("Automatic Vercel Preview builds block the Stripe Sandbox without exposing credentials", () => {
  const script = fileURLToPath(new URL("../scripts/check-admin-build.mjs", import.meta.url));
  const run = (vars) => spawnSync(process.execPath, [script], {
    encoding: "utf8",
    env: { ...process.env, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_synthetic_test_only", ...vars },
  });
  const wrong = run({
    VERCEL_ENV: "preview",
    NEXT_PUBLIC_SUPABASE_URL: stripeSandbox,
    ADMIN_PREVIEW_SUPABASE_PROJECT_REF: "yydgdapzlrjmlrjgijkj",
  });
  assert.equal(wrong.status, 1);
  assert.match(wrong.stderr, /BLOCKED:/);
  assert.doesNotMatch(wrong.stderr + wrong.stdout, /pcatuxtenluqzjzzwsvl/);

  // A correct project URL is not usable when the auth client key is absent.
  for (const badKey of ["", "   ", "qa_dummy_publishable_key", "placeholder_fake_key"]) {
    const missing = run({
      VERCEL_ENV: "preview",
      NEXT_PUBLIC_SUPABASE_URL: staging,
      ADMIN_PREVIEW_SUPABASE_PROJECT_REF: "yydgdapzlrjmlrjgijkj",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: badKey,
    });
    assert.equal(missing.status, 1);
    assert.match(missing.stderr, /publishable key is missing or a test placeholder/);
    assert.doesNotMatch(missing.stderr + missing.stdout, /sb_publishable_synthetic_test_only/);
  }

  const ready = run({
    VERCEL_ENV: "preview",
    NEXT_PUBLIC_SUPABASE_URL: staging,
    ADMIN_PREVIEW_SUPABASE_PROJECT_REF: "yydgdapzlrjmlrjgijkj",
  });
  assert.equal(ready.status, 0, ready.stderr);
  const prod = run({ VERCEL_ENV: "production", NEXT_PUBLIC_SUPABASE_URL: production });
  assert.equal(prod.status, 0, prod.stderr);
  const local = run({ VERCEL_ENV: "", NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321" });
  assert.equal(local.status, 0, local.stderr);
});
