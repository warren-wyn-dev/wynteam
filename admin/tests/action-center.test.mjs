import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (file) => readFileSync(new URL(file, import.meta.url), "utf8");
const source = read("../lib/admin-action-center.ts");
const page = read("../app/(admin)/action-center/page.tsx");
const nav = read("../lib/admin-nav.ts");
const overview = read("../app/(admin)/page.tsx");
const ci = read("../../.github/workflows/ci.yml");

test("Action Center uses the authenticated Admin role and is read-only", () => {
  assert.match(page, /await requireAdminRole\(\)/);
  assert.match(page, /fetchActionCenter\(role\)/);
  assert.match(source, /role === "admin" \? settle\(fetchAdminFoodOverview\)/);
  assert.match(source, /if \(role === "admin" && food !== null\)/);
  assert.match(source, /\.select\("id, target_type, created_at"/);
  assert.doesNotMatch(source, /service_role|\.insert\(|\.update\(|\.delete\(|\.upsert\(/);
  assert.doesNotMatch(page, /<form|onSubmit=|use server|recipient_phone|contact_name/);
});

test("Action Center does not leak Merchant applicant or Food customer fields into rendered actions", () => {
  assert.match(source, /fetchMerchantApplications\("pending"\)/);
  assert.match(source, /\/\/ Never return merchant applicant PII[\s\S]*items: \[\],/);
  assert.doesNotMatch(source, /\.phone|\.address|\.contact_name|\.recipient_name|\.recipient_phone/);
  assert.doesNotMatch(page, /\.detail|\.target_id|\.phone|\.address|\.recipient/);
});

test("Independent source errors never render false zero or leak backend error messages", () => {
  assert.match(source, /Promise\.all\(\[/);
  assert.match(source, /return \{ state: "unavailable" \}/);
  assert.match(source, /countLabel: reports\.state === "ready"/);
  assert.match(source, /countLabel: merchants\.state === "ready"/);
  assert.match(page, /section\.state === "unavailable"/);
  assert.match(page, /ไม่ได้หมายความว่าไม่มีงานค้าง/);
});

test("New Action Center stays inside Overview workspace and guest route security smoke", () => {
  assert.match(nav, /href: "\/action-center", label: "งานรอดำเนินการ"/);
  assert.match(overview, /href: "\/action-center"/);
  assert.ok(ci.includes(" /action-center "));
  assert.match(page, /lg:grid-cols-2/);
  assert.match(page, /min-h-11/);
});
