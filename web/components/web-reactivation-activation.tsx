"use client";

import { useEffect } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

const FIRST_TOUCH_DELAY_MS = 3_000;
const CONTINUOUS_USE_ACTIVATION_MS = 5 * 60 * 1000;

async function markSeen(client: SupabaseClient): Promise<boolean> {
  const result = await client.rpc("mark_web_reactivation_seen");
  return result.error ? false : result.data === true;
}

/**
 * Web Beta 1 only.
 * First signed-in app session records "seen" but does not activate immediately.
 * A later return (visibility change / new session) or five minutes of continuous
 * use marks the account activated and permanently stops reactivation Push.
 */
export function WebReactivationActivation() {
  useEffect(() => {
    const client = getSupabaseBrowserClient();
    if (!client) return;

    let currentUserId: string | null = null;
    let doneForUser: string | null = null;
    let firstTimer: ReturnType<typeof setTimeout> | null = null;
    let activationTimer: ReturnType<typeof setTimeout> | null = null;

    const touch = async () => {
      if (!currentUserId || doneForUser === currentUserId) return;
      if (await markSeen(client)) doneForUser = currentUserId;
    };

    const schedule = (userId: string | null | undefined) => {
      currentUserId = userId ?? null;
      doneForUser = null;
      if (firstTimer) clearTimeout(firstTimer);
      if (activationTimer) clearTimeout(activationTimer);
      if (!currentUserId) return;
      firstTimer = setTimeout(() => void touch(), FIRST_TOUCH_DELAY_MS);
      activationTimer = setTimeout(() => void touch(), CONTINUOUS_USE_ACTIVATION_MS);
    };

    const { data } = client.auth.onAuthStateChange((_event, session) => {
      schedule(session?.user?.id);
    });

    const onVisibility = () => {
      if (document.visibilityState === "visible") void touch();
    };
    document.addEventListener("visibilitychange", onVisibility);

    return () => {
      if (firstTimer) clearTimeout(firstTimer);
      if (activationTimer) clearTimeout(activationTimer);
      document.removeEventListener("visibilitychange", onVisibility);
      data.subscription.unsubscribe();
    };
  }, []);

  return null;
}
