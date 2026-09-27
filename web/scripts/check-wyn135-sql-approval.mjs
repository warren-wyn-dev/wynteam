// WYN-135 SQL requires an explicit, standalone Founder decision.
// Never treat an example, a rejection, or an APPROVAL_REQUIRED note as approval.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const DECISION = /^### DECISION — \[\d{4}-\d{2}-\d{2}\] WYN-135 production SQL$/;

export function hasFounderSqlApproval(markdown) {
  const decisions = [];
  let section = null;
  let fence = null;

  for (const line of markdown.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (/^(\x60{3,}|~{3,})/.test(trimmed)) {
      const marker = trimmed[0];
      fence = fence === marker ? null : fence ?? marker;
      continue;
    }
    if (fence) continue;
    if (line.startsWith("### ")) {
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
  return statuses.length === 1
    && statuses[0] === "- Status: APPROVED"
    && lines.includes("- Approved by: Founder")
    && lines.includes("- Scope: WYN-135 production SQL only");
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const filepath = process.argv[2];
  if (!filepath) {
    console.error("Expected the version-controlled APPROVALS.md path.");
    process.exitCode = 1;
  } else {
    try {
      if (!hasFounderSqlApproval(readFileSync(filepath, "utf8"))) {
        console.error("WYN-135 SQL is not explicitly approved by the Founder.");
        process.exitCode = 1;
      }
    } catch (error) {
      console.error("Cannot validate WYN-135 Founder approval:", error);
      process.exitCode = 1;
    }
  }
}
