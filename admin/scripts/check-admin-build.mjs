#!/usr/bin/env node
/**
 * Guard remote Vercel builds, including automatic Git integrations that do
 * not go through our manual GitHub Actions deployment workflow.
 * Local/offline CI builds have no VERCEL_ENV and never contact real services.
 */
import { validateAdminBackend } from "./check-admin-environment.mjs";

const target = process.env.VERCEL_ENV;
if (target) {
  try {
    validateAdminBackend({
      target,
      url: process.env.NEXT_PUBLIC_SUPABASE_URL,
      previewRef: process.env.ADMIN_PREVIEW_SUPABASE_PROJECT_REF,
    });
    process.stdout.write("PASS: Admin Vercel build environment is isolated and approved\n");
  } catch (error) {
    process.stderr.write("BLOCKED: " + (error instanceof Error ? error.message : "Invalid Admin backend") + "\n");
    process.exitCode = 1;
  }
}
