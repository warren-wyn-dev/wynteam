// Isolated WYNOS Web Beta 2 staging: fail closed before any preview deploy.
// Do not import this file into browser code; it reads CI-only environment values.
const STAGING_REF = "yydgdapzlrjmlrjgijkj";
const PROD_REF = "kqokpocajhfbidcxpvhh";

export function assertIsolatedStaging(env) {
  const names=["STAGING_SUPABASE_URL","STAGING_SUPABASE_PUBLISHABLE_KEY","PRODUCTION_SUPABASE_URL","PRODUCTION_SUPABASE_PUBLISHABLE_KEY","STAGING_VERCEL_PROJECT_ID","PRODUCTION_VERCEL_PROJECT_ID","VERCEL_ORG_ID"];
  for (const name of names) {
    if (!env[name] || !String(env[name]).trim()) throw new Error(`Missing required staging guard variable: ${name}`);
  }
  function checkUrl(value, expectedRef, label) {
    const expected = `https://${expectedRef}.supabase.co`;
    if (value!==expected && value!==expected+"/") throw new Error(`${label} must match its explicitly approved Supabase project`);
  }
  checkUrl(env.STAGING_SUPABASE_URL, STAGING_REF, "Staging Supabase URL");
  checkUrl(env.PRODUCTION_SUPABASE_URL, PROD_REF, "Production Supabase URL");
  if (!env.STAGING_SUPABASE_PUBLISHABLE_KEY.startsWith("sb_publishable_"))
    throw new Error("Staging must use a publishable key, never a secret or service_role key");
  if (env.STAGING_SUPABASE_PUBLISHABLE_KEY===env.PRODUCTION_SUPABASE_PUBLISHABLE_KEY)
    throw new Error("Staging and production Supabase keys must differ");
  if (!/^prj_[A-Za-z0-9]+$/.test(env.STAGING_VERCEL_PROJECT_ID) || !/^prj_[A-Za-z0-9]+$/.test(env.PRODUCTION_VERCEL_PROJECT_ID))
    throw new Error("Both Vercel project IDs must be explicit and valid");
  if (env.STAGING_VERCEL_PROJECT_ID===env.PRODUCTION_VERCEL_PROJECT_ID)
    throw new Error("Staging and production Vercel projects must be different");
  return true;
}

if (process.argv[1]?.endsWith("/assert-isolated-staging.mjs")) {
  try {
    assertIsolatedStaging(process.env);
    console.log("Isolated staging identifiers and publishable-key class verified (no secrets printed).");
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Staging environment validation failed");
    process.exitCode = 1;
  }
}
