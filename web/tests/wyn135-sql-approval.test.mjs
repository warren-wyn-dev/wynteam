import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { hasFounderSqlApproval } from "../scripts/check-wyn135-sql-approval.mjs";

const sqlDigest = createHash("sha256").update(readFileSync(
  new URL("../../supabase/migrations_web_beta2_club_chat_actions.sql", import.meta.url),
)).digest("hex");
const check = (markdown, digest = sqlDigest) => hasFounderSqlApproval(markdown, digest);

const approved = [
  "### DECISION — [2026-09-27] WYN-135 production SQL",
  "- Approved by: Founder",
  "- Scope: WYN-135 production SQL only",
  `- Migration SHA-256: ${sqlDigest}`,
  "- Status: APPROVED",
].join("\n");

test("manual WYN-135 SQL gate requires one standalone, structured Founder decision", () => {
  assert.equal(check(approved), true);
  assert.equal(hasFounderSqlApproval(approved), false);
  assert.equal(check(approved, "a".repeat(64) === sqlDigest ? "b".repeat(64) : "a".repeat(64)), false);
  assert.equal(check(approved.replace(`- Migration SHA-256: ${sqlDigest}`, "- Migration SHA-256: " + "0".repeat(64))), false);
  assert.equal(check(approved.replace(`- Migration SHA-256: ${sqlDigest}`, "")), false);
  assert.equal(check(approved + `\n- Migration SHA-256: ${sqlDigest}`), false);
  assert.equal(check("NOT APPROVED WYN-135 production SQL"), false);
  assert.equal(check("### APPROVAL_REQUIRED — WYN-135\n- Status: APPROVED"), false);
  assert.equal(check(approved.replace("APPROVED", "DENIED")), false);
  assert.equal(check(approved.replace("APPROVED", "NOT APPROVED")), false);
  assert.equal(check(approved.replace("- Approved by: Founder", "- Approved by: CI")), false);
  assert.equal(check(approved.replace("- Scope: WYN-135 production SQL only", "- Scope: WYN-135 web")), false);
  assert.equal(check(approved + "\n- Status: DENIED"), false);
  assert.equal(check(approved + "\n\n" + approved), false);
  assert.equal(check("~~~markdown\n" + approved + "\n~~~"), false);
  assert.equal(check("````markdown\n```\n" + approved + "\n```\n````"), false);
  assert.equal(check("~~~~markdown\n~~~\n" + approved + "\n~~~\n~~~~"), false);
  assert.equal(check(approved + "\n<!-- unclosed comment"), false);
  assert.equal(check("<!--\n" + approved + "\n-->"), false);
  assert.equal(check("<!-- " + approved + " -->"), false);
  assert.equal(check("<!--\n" + approved), false);
  assert.equal(check(
    approved.replace("- Status: APPROVED", "<!-- - Status: APPROVED -->")
  ), false);
  assert.equal(check("<!--\n" + approved + "\n-->\n" + approved), true);
  assert.equal(check(approved + "\n<!--\n" + approved + "\n-->"), true);
  assert.equal(check("### REJECTED WYN-135\nNOT APPROVED WYN-135 production SQL"), false);
});
