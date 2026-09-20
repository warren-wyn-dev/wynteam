"use client";

import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Staged-rollout gate (WYN-125). Calls the same `is_developer_account`
 * Supabase RPC components/settings-route.tsx's VersionFooter already uses
 * for the Beta5 version label — this hook exists so new user-facing
 * features (WYN-182's 4 new pull-to-refresh screens) can reuse that exact
 * check instead of re-inlining the RPC call at every new call site.
 *
 * Fails closed: returns false until the RPC resolves with a positive `true`,
 * and stays false on any error. A feature gated by this only ever turns on
 * for confirmed developer accounts, never as a fallback default.
 */
export function useIsDeveloperAccount(client: SupabaseClient | null | undefined): boolean {
  const [isDeveloper, setIsDeveloper] = useState(false);
  useEffect(() => {
    if (!client) return;
    let live = true;
    void client.rpc("is_developer_account").then(({ data, error }) => {
      if (live && !error && data === true) setIsDeveloper(true);
    });
    return () => {
      live = false;
    };
  }, [client]);
  return isDeveloper;
}
