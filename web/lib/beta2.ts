"use client";

import type { SupabaseClient } from "@supabase/supabase-js";

import { useIsDeveloperAccount } from "@/lib/use-is-developer-account";

/**
 * Web Beta2 feature switches (Founder decision 2026-09-27: "มาพัฒนา Beta2
 * ก่อน อย่าพึ่งปล่อยจริง").
 *
 * Beta2 work ships to wynos.online like everything else, but each feature
 * stays visible to developer accounts only (`is_developer_account()`,
 * fail-closed) until the Founder releases it. Releasing a feature means
 * flipping its entry here to `true` in a PR that records the Founder's
 * approval in .wyn/company/APPROVALS.md.
 *
 * This is product gating for the UI. Any new server capability behind a
 * Beta2 feature must also check `is_developer_account()` on the server until
 * release, so the feature cannot be reached by calling the API directly.
 */
export const BETA2_RELEASED = {
  /** WYN-159: Threads-style chat. */
  chatThreads: false,
  /** WYN-135: edit, pin and search messages in Club chat. */
  clubChatActions: false,
  /** WYN-137: Club announcements. */
  clubAnnouncements: false,
} as const;

export type Beta2Feature = keyof typeof BETA2_RELEASED;

/** Whether this account may use a Beta2 feature: released to everyone, or a confirmed developer. */
export function useBeta2Feature(feature: Beta2Feature, client: SupabaseClient | null | undefined, userId?: string): boolean {
  const isDeveloper = useIsDeveloperAccount(client, userId);
  return BETA2_RELEASED[feature] || isDeveloper;
}
