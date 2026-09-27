import assert from "node:assert/strict";
import { test } from "node:test";

import { hasFounderSqlApproval } from "../scripts/check-wyn135-sql-approval.mjs";

const approved = [
  "### DECISION — [2026-09-27] WYN-135 production SQL",
  "- Approved by: Founder",
  "- Scope: WYN-135 production SQL only",
  "- Status: APPROVED",
].join("\n");

test("manual WYN-135 SQL gate requires one standalone, structured Founder decision", () => {
  assert.equal(hasFounderSqlApproval(approved), true);
  assert.equal(hasFounderSqlApproval("NOT APPROVED WYN-135 production SQL"), false);
  assert.equal(hasFounderSqlApproval("### APPROVAL_REQUIRED — WYN-135\n- Status: APPROVED"), false);
  assert.equal(hasFounderSqlApproval(approved.replace("APPROVED", "DENIED")), false);
  assert.equal(hasFounderSqlApproval(approved.replace("APPROVED", "NOT APPROVED")), false);
  assert.equal(hasFounderSqlApproval(approved.replace("- Approved by: Founder", "- Approved by: CI")), false);
  assert.equal(hasFounderSqlApproval(approved.replace("- Scope: WYN-135 production SQL only", "- Scope: WYN-135 web")), false);
  assert.equal(hasFounderSqlApproval(approved + "\n- Status: DENIED"), false);
  assert.equal(hasFounderSqlApproval(approved + "\n\n" + approved), false);
  assert.equal(hasFounderSqlApproval("~~~markdown\n" + approved + "\n~~~"), false);
  assert.equal(hasFounderSqlApproval("### REJECTED WYN-135\nNOT APPROVED WYN-135 production SQL"), false);
});
