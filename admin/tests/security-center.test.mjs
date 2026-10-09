import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

test("Security Center defaults OFF and guest access remains role-gated", () => {
  const page = read("../app/(admin)/security-center/page.tsx");
  const nav = read("../lib/admin-nav.ts");
  const ci = read("../../.github/workflows/ci.yml");
  assert.match(page, /await requireAdminRole\(\)/);
  assert.match(page, /process\.env\.NEXT_PUBLIC_ADMIN_SECURITY_CENTER_ENABLED !== "true"/);
  assert.match(page, /notFound\(\)/);
  assert.match(nav, /process\.env\.NEXT_PUBLIC_ADMIN_SECURITY_CENTER_ENABLED === "true"/);
  assert.match(nav, /href: "\/security-center"/);
  assert.match(ci, /for route in \/ \/security-center \/social/);
});

test("Security snapshot fetches only current user's MFA and AAL without a privileged service key", () => {
  const source = read("../lib/admin-security-snapshot.ts");
  assert.match(source, /await requireAdminRole\(\)/);
  assert.match(source, /supabase\.auth\.mfa\.listFactors\(\)/);
  assert.match(source, /supabase\.auth\.mfa\.getAuthenticatorAssuranceLevel\(\)/);
  assert.match(source, /factor\.status === "verified"/);
  assert.match(source, /factor_type === "totp"/);
  assert.match(source, /factorsResult \? verifiedFactors\.filter/);
  assert.match(source, /otherDevices: "unavailable"/);
  assert.doesNotMatch(source, /\.enroll\(|\.unenroll\(|\.challenge\(|\.verify\(|\.signOut\(|service_role|admin\.deleteUser/);
});

test("Security UI never exposes token, MFA seeds or pretends all sessions can be revoked", () => {
  const page = read("../app/(admin)/security-center/page.tsx");
  assert.doesNotMatch(page, /access_token|refresh_token|factor\.id|totp\.qr_code|totp\.secret/);
  assert.doesNotMatch(page, /onSubmit|<form|use server|\.update\(/);
  assert.match(page, /ยังไม่มีแหล่งข้อมูลที่ตรวจรับ/);
  assert.match(page, /ยังไม่มีปุ่มเปิด ปิด หรือบังคับใช้ MFA/);
  assert.match(page, /snapshot\.mfa\.status === "available"/);
  assert.match(page, /md:grid-cols-2/);
});
