import { createClient } from "@/lib/supabase/server";
import { requireAdminRole } from "@/lib/auth";

export type AdminSecuritySnapshot = {
  checkedAt: string;
  session: "verified";
  mfa: {
    status: "available" | "unavailable";
    verifiedTotp: number | null;
    verifiedPhone: number | null;
    assurance: "aal1" | "aal2" | "unknown";
    nextAssurance: "aal1" | "aal2" | "unknown";
  };
  otherDevices: "unavailable";
};

/**
 * The Supabase Auth service is the authority. This read-only snapshot does
 * NOT enroll/unenroll MFA, change any policy, persist tokens or query other
 * operators' authentication data.
 */
export async function fetchOwnAdminSecuritySnapshot(): Promise<AdminSecuritySnapshot> {
  await requireAdminRole(); // Server-side session + platform-role gate.
  const checkedAt = new Date().toISOString();
  const supabase = await createClient();
  const [factors, assurance] = await Promise.allSettled([
    supabase.auth.mfa.listFactors(),
    supabase.auth.mfa.getAuthenticatorAssuranceLevel(),
  ]);

  const factorsResult = factors.status === "fulfilled" && !factors.value.error
    ? factors.value.data : null;
  const assuranceResult = assurance.status === "fulfilled" && !assurance.value.error
    ? assurance.value.data : null;

  const verifiedFactors = factorsResult?.all?.filter(
    (factor) => factor.status === "verified",
  ) ?? [];

  const currentLevel = assuranceResult?.currentLevel;
  const nextLevel = assuranceResult?.nextLevel;

  return {
    checkedAt,
    session: "verified",
    mfa: {
      status: factorsResult && assuranceResult ? "available" : "unavailable",
      // If Auth fails, show unknown rather than falsely claiming 0 factors.
      verifiedTotp: factorsResult ? verifiedFactors.filter((f) => f.factor_type === "totp").length : null,
      verifiedPhone: factorsResult ? verifiedFactors.filter((f) => f.factor_type === "phone").length : null,
      assurance: currentLevel === "aal1" || currentLevel === "aal2" ? currentLevel : "unknown",
      nextAssurance: nextLevel === "aal1" || nextLevel === "aal2" ? nextLevel : "unknown",
    },
    // Supabase client session metadata alone does not list all remote devices.
    otherDevices: "unavailable",
  };
}
