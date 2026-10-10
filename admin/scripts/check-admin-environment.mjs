#!/usr/bin/env node
/**
 * Admin-only release preflight. Never print keys or connect to a database.
 * Preview must use an explicitly approved, isolated Admin staging project.
 * Production must use the existing WYNOS production backend.
 *
 * Run before invoking the manual Admin Vercel deploy workflow. This script
 * does not mutate Vercel, Supabase, Stripe or the Food/Merchant applications.
 */
import { pathToFileURL } from "node:url";

const PRODUCTION_REF = "kqokpocajhfbidcxpvhh";
const STRIPE_SANDBOX_REF = "pcatuxtenluqzjzzwsvl";

export function validateAdminBackend({ target, url, previewRef }) {
  if (target !== "preview" && target !== "production") {
    throw new Error("Admin deploy target must be preview or production");
  }

  let parsed;
  try {
    parsed = new URL(url || "");
  } catch {
    throw new Error("Missing or malformed Admin Supabase URL");
  }
  if (parsed.protocol !== "https:" || parsed.username || parsed.password || parsed.port || parsed.pathname !== "/" || parsed.search || parsed.hash) {
    throw new Error("Admin deployment must use the canonical HTTPS Supabase project URL");
  }

  const match = /^([a-z0-9-]+)\.supabase\.co$/.exec(parsed.hostname);
  if (!match) throw new Error("Admin deployment backend must be a Supabase project URL");
  const actualRef = match[1];

  if (target === "production") {
    if (actualRef !== PRODUCTION_REF) {
      throw new Error("Admin Production backend is not the approved WYNOS project");
    }
  } else {
    if (!/^[a-z0-9]{20}$/.test(previewRef || "")) {
      throw new Error("Set ADMIN_PREVIEW_SUPABASE_PROJECT_REF to an isolated, active Admin staging project");
    }
    if (previewRef === PRODUCTION_REF || previewRef === STRIPE_SANDBOX_REF) {
      throw new Error("Admin Preview cannot use WYNOS Production or the Stripe Sandbox");
    }
    if (actualRef !== previewRef) {
      throw new Error("Admin Preview backend does not match the approved staging project");
    }
  }
  return { target, projectRef: actualRef };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const result = validateAdminBackend({
      target: process.argv[2],
      url: process.env.SUPABASE_URL,
      previewRef: process.env.ADMIN_PREVIEW_SUPABASE_PROJECT_REF,
    });
    process.stdout.write("PASS: Admin " + result.target + " backend project validated (no credentials logged)\n");
  } catch (error) {
    process.stderr.write("BLOCKED: " + (error instanceof Error ? error.message : "Admin environment preflight failed") + "\n");
    process.exitCode = 1;
  }
}
