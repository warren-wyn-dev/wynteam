// WYN-135 SQL requires an explicit, standalone Founder decision.
// Never treat an example, a rejection, or an APPROVAL_REQUIRED note as approval.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const DECISION = /^### DECISION — \[\d{4}-\d{2}-\d{2}\] WYN-135 production SQL$/;

export function hasFounderSqlApproval(markdown, migrationSha256) {
  if (!/^[a-f0-9]{64}$/.test(migrationSha256 ?? "")) return false;
  const decisions = [];
  let section = null;
  let fence = null;

  // An approval inside an HTML comment is not a Founder decision. Remove
  // complete comments and fail closed for an unterminated opening comment.
  const visible = markdown.replace(/<!--[\s\S]*?-->/g, "");
  if (visible.includes("<!--")) return false; // Unterminated comment: fail closed.

  for (const line of visible.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (fence) {
      // CommonMark closes only with the SAME marker and at least the opening
      // length; an inner 3-backtick fence cannot close a 4-backtick example.
      const closing = /^(`{3,}|~{3,})[ \t]*$/.exec(trimmed);
      if (closing && closing[1][0] === fence.marker && closing[1].length >= fence.length)
        fence = null;
      continue;
    }
    const opening = /^(`{3,}|~{3,})/.exec(trimmed);
    if (opening) {
      fence = { marker: opening[1][0], length: opening[1].length };
      continue;
    }
    // Any Markdown heading ends the previous decision; fields from a later
    // unrelated section cannot complete an incomplete Founder approval.
    if (/^#{1,6}[ \t]+/.test(line)) {
      if (section) decisions.push(section);
      section = DECISION.test(line) ? [] : null;
    } else if (section) {
      section.push(line);
    }
  }
  if (section) decisions.push(section);
  if (decisions.length !== 1) return false;

  const lines = decisions[0];
  const statuses = lines.filter((line) => line.startsWith("- Status: "));
  const digests = lines.filter((line) => line.startsWith("- Migration SHA-256: "));
  return statuses.length === 1
    && statuses[0] === "- Status: APPROVED"
    && lines.includes("- Approved by: Founder")
    && lines.includes("- Scope: WYN-135 production SQL only")
    && digests.length === 1
    && digests[0] === `- Migration SHA-256: ${migrationSha256}`;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const filepath = process.argv[2];
  if (!filepath) {
    console.error("Expected the version-controlled APPROVALS.md path.");
    process.exitCode = 1;
  } else {
    try {
      const migration = readFileSync(new URL("../../supabase/migrations_web_beta2_club_chat_actions.sql", import.meta.url));
      const digest = createHash("sha256").update(migration).digest("hex");
      if (!hasFounderSqlApproval(readFileSync(filepath, "utf8"), digest)) {
        console.error(`WYN-135 production SQL needs explicit Founder approval for migration SHA-256: ${digest}`);
        process.exitCode = 1;
      }
    } catch (error) {
      console.error("Cannot validate WYN-135 Founder approval:", error);
      process.exitCode = 1;
    }
  }
}
