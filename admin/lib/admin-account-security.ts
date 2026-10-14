import { ADMIN_SYSTEMS, type AdminSystem } from "@/lib/admin-systems";
import { adminCan, requireAdminRole } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export type AccountAssurance = {
  currentLevel: "aal1" | "aal2";
  nextLevel: "aal1" | "aal2" | null;
};

export type AccountFactorCounts = {
  verified: number;
  unverified: number;
  totp: number;
  phone: number;
  webauthn: number;
};

export type AccountSecurityOverview = {
  assurance: AccountAssurance | null;
  factors: AccountFactorCounts | null;
  permissionSource: "system" | "legacy";
  superAdmin: boolean;
  permissions: Array<{ system: AdminSystem; view: boolean; edit: boolean }>;
};

/**
 * Read only the authenticated caller's MFA metadata and effective Admin access.
 * MFA state is descriptive: it never grants access or changes the existing gate.
 * No user identifier is accepted and no factor IDs, names, phones, tokens or
 * enrollment secrets leave this server-side data boundary.
 */
export async function fetchAccountSecurityOverview(): Promise<AccountSecurityOverview> {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "account")) throw new Error("Account access is required");

  const supabase = await createClient();
  const [assuranceResult, factorsResult] = await Promise.allSettled([
    supabase.auth.mfa.getAuthenticatorAssuranceLevel(),
    supabase.auth.mfa.listFactors(),
  ]);

  return {
    assurance: assuranceResult.status === "fulfilled" && !assuranceResult.value.error
      ? readAssurance(assuranceResult.value.data) : null,
    factors: factorsResult.status === "fulfilled" && !factorsResult.value.error
      ? countFactors(factorsResult.value.data) : null,
    permissionSource: ctx.access.available ? "system" : "legacy",
    superAdmin: ctx.access.available && ctx.access.superAdmin,
    permissions: ADMIN_SYSTEMS.map((system) => ({
      system,
      view: adminCan(ctx, system),
      edit: adminCan(ctx, system, "edit"),
    })),
  };
}

function readAssurance(data: unknown): AccountAssurance | null {
  if (!data || typeof data !== "object") return null;
  const { currentLevel, nextLevel } = data as Record<string, unknown>;
  if (currentLevel !== "aal1" && currentLevel !== "aal2") return null;
  if (nextLevel !== null && nextLevel !== "aal1" && nextLevel !== "aal2") return null;
  return { currentLevel, nextLevel };
}

function countFactors(data: unknown): AccountFactorCounts | null {
  if (!data || typeof data !== "object" || !("all" in data) || !Array.isArray(data.all)) return null;
  const counts: AccountFactorCounts = { verified: 0, unverified: 0, totp: 0, phone: 0, webauthn: 0 };
  for (const factor of data.all) {
    if (!factor || typeof factor !== "object") return null;
    const { status, factor_type: type } = factor as Record<string, unknown>;
    if (status !== "verified" && status !== "unverified") return null;
    if (type !== "totp" && type !== "phone" && type !== "webauthn") return null;
    if (status === "verified") {
      counts.verified++;
      counts[type]++;
    } else {
      counts.unverified++;
    }
  }
  return counts;
}
