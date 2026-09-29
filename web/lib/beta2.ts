"use client";

import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Legacy compatibility switches for the three features built during the
 * short-lived WYNOS Web Beta2 track.
 *
 * Founder decision 2026-09-29:
 * - release all three features to every eligible WYNOS Web user;
 * - suspend the Web Beta2 development track;
 * - continue future web development under WYNOS Web Beta1, with new
 *   user-facing features staged to developer accounts first.
 *
 * Do not add new features to this map. New Web Beta1 work should use the
 * normal developer-account staged-rollout mechanism directly.
 */
export const BETA2_RELEASED = {
  /** WYN-159: Threads-style chat. Public since 2026-09-29. */
  chatThreads: true,
  /** WYN-135: edit, pin and search messages in Club chat. Public since 2026-09-29. */
  clubChatActions: true,
  /** WYN-137: Club announcements. Public since 2026-09-29. */
  clubAnnouncements: true,
} as const;

export type Beta2Feature = keyof typeof BETA2_RELEASED;

/**
 * Compatibility hook kept so existing call sites do not need a risky release
 * refactor. The retired Beta2 feature set is permanently public.
 */
export function useBeta2Feature(
  feature: Beta2Feature,
  client: SupabaseClient | null | undefined,
  userId?: string,
): boolean {
  void client;
  void userId;
  return BETA2_RELEASED[feature];
}
