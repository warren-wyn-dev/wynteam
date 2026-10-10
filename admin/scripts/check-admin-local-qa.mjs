#!/usr/bin/env node
/**
 * WYNOS Admin free-only QA: fail-closed local Supabase preflight.
 *
 * This checks the *target*, not the service itself. It never connects to
 * Supabase, Vercel, Stripe or Production and never logs credentials.
 * Existing Vercel production/preview guards remain separate.
 */
import { pathToFileURL } from "node:url";

export function validateLocalQaTarget({
  url,
  publishableKey,
  vercelEnv,
}) {
  if (vercelEnv) {
    throw new Error("Local Admin QA cannot run in a Vercel deployment environment");
  }

  let endpoint;
  try {
    endpoint = new URL(url || "");
  } catch {
    throw new Error("Set NEXT_PUBLIC_SUPABASE_URL to an isolated local Supabase API");
  }

  const allowedHosts = new Set(["127.0.0.1", "localhost", "[::1]"]);
  if (endpoint.protocol !== "http:" || !allowedHosts.has(endpoint.hostname) ||
      !endpoint.port || endpoint.pathname !== "/" || endpoint.search ||
      endpoint.hash || endpoint.username || endpoint.password) {
    throw new Error("Free Admin QA must use a localhost-only HTTP Supabase API with an explicit port");
  }

  if (!publishableKey || !publishableKey.trim() ||
      /^(qa_dummy|example|placeholder|replace_me)/i.test(publishableKey.trim())) {
    throw new Error("Use the local Supabase CLI anon/publishable key, not a placeholder");
  }

  return { scope: "local-only" };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    validateLocalQaTarget({
      url: process.env.NEXT_PUBLIC_SUPABASE_URL,
      publishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
      vercelEnv: process.env.VERCEL_ENV || process.env.VERCEL,
    });
    process.stdout.write("PASS: Admin QA target is local-only (service health still requires testing)\n");
  } catch (error) {
    process.stderr.write("BLOCKED: " +
      (error instanceof Error ? error.message : "Invalid local QA target") + "\n");
    process.exitCode = 1;
  }
}
