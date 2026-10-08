#!/usr/bin/env node
// CI-only creator/remover of ephemeral local Next route.
// The checked-in TSX fixture lives under /tests, never in /app.
import { copyFileSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const target = resolve(root, "app", "finance-qa-ci-fixture");
const source = resolve(root, "tests", "finance-qa-browser-fixture.page.tsx");
if (process.env.CI !== "true"
    || process.env.WYNOS_FINANCE_BROWSER_CI_ACK !== "ephemeral-local-only"
    || process.env.NEXT_PUBLIC_WYNOS_FINANCE_QA_PREVIEW !== "true"
    || process.env.NEXT_PUBLIC_SUPABASE_URL !== "https://pcatuxtenluqzjzzwsvl.supabase.co") {
  throw new Error("Refusing local Finance browser fixture outside explicit CI QA sandbox");
}
if (process.argv[2] === "--cleanup") {
  if (existsSync(target)) rmSync(target, { recursive: true, force: true });
  console.log("Ephemeral Finance QA browser route cleaned");
} else {
  if (existsSync(target)) throw new Error("Refusing to overwrite preexisting finance route");
  mkdirSync(target);
  copyFileSync(source, resolve(target, "page.tsx"));
  console.log("Created disposable Finance QA browser fixture, local runner only");
}
