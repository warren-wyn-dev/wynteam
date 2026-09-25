import type { SupabaseClient } from "@supabase/supabase-js";

/** Browser reads are display-only. Every paid feature must authorize its
 * entitlement on a trusted server after verified billing webhook processing. */
export type PlusMembership = {
 tier: "plus";
 status: "incomplete" | "trialing" | "active" | "past_due" | "canceled" | "unpaid";
 current_period_end: string | null;
 cancel_at_period_end: boolean;
};
export type PlusLookup = { available: boolean; membership: PlusMembership | null };

export function hasCurrentPlusMembership(
 membership: PlusMembership | null,
 now = Date.now(),
): boolean {
 if (!membership || membership.tier !== "plus") return false;
 if (membership.status !== "active" && membership.status !== "trialing") return false;
 if (!membership.current_period_end) return false;
 const expiry = Date.parse(membership.current_period_end);
 return Number.isFinite(expiry) && expiry > now;
}

export async function fetchPlusMembership(
 client: SupabaseClient,
 userId: string,
): Promise<PlusLookup> {
 const result = await client.from("wynos_plus_memberships")
   .select("tier,status,current_period_end,cancel_at_period_end")
   .eq("user_id", userId)
   .maybeSingle();
 if (result.error) {
   // No schema migration yet = Plus isn't launched; do not pretend to enroll.
   if (result.error.code === "42P01" || result.error.code === "PGRST205")
     return { available: false, membership: null };
   throw result.error;
 }
 return { available: true, membership: (result.data ?? null) as PlusMembership | null };
}
