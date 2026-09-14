import { writeFileSync } from "node:fs";

// The full parity closure lives in the immediately previous audited patch
// revision. Re-run that exact implementation with the two marker-boundary
// joins corrected; this keeps the recovery commit small and reviewable.
const auditedPatchUrl =
  "https://raw.githubusercontent.com/warren-wyn-dev/wynteam/5627c6dd394ac3f6efc85cbf4f77ae6e38c11bfc/tools/wyn158_structural_parity_patch.mjs";
const response = await fetch(auditedPatchUrl);
if (!response.ok) throw new Error(`Unable to load audited parity patch: ${response.status}`);
let source = await response.text();

const fixes = [
  ['newCommentRow + "function PostDetailInner("', 'newCommentRow'],
  ['newReturn + "export function PostDetailRoute"', 'newReturn'],
];
for (const [from, to] of fixes) {
  if (!source.includes(from)) throw new Error(`Missing audited patch fix target: ${from}`);
  source = source.replace(from, to);
}

const implementationPath = new URL("./.wyn158-final-parity-impl.mjs", import.meta.url);
writeFileSync(implementationPath, source);
await import(`${implementationPath.href}?run=${Date.now()}`);
