"use client";

import { useEffect } from "react";

import { resyncPushRegistration } from "@/lib/push-notifications";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

const REACTIVATION_ACTIVE_AFTER_MS = 10 * 60 * 1000;
const REACTIVATION_TIMER_GRACE_MS = 15_000;

/**
 * Keeps Push on for accounts that turned it on on this device: after a
 * token rotation, a token the server dropped, or switching back to the
 * account, the current token is registered again (once per page load).
 *
 * It also marks the new-user reactivation campaign as complete when someone
 * returns after onboarding, or remains in WYNOS for 10 minutes. The RPC is
 * intentionally best-effort so a campaign/backend issue can never block the
 * signed-in app shell.
 */
export function PushResync() {
  useEffect(() => {
    const client = getSupabaseBrowserClient();
    if (!client) return;

    let resyncTimer: ReturnType<typeof setTimeout> | null = null;
    let activationTimer: ReturnType<typeof setTimeout> | null = null;
    let sustainedUseTimer: ReturnType<typeof setTimeout> | null = null;

    const markReactivationActivated = async () => {
      try {
        await client.rpc("mark_web_reactivation_activated");
      } catch {
        // Best effort only. Push resync and the rest of the app stay usable.
      }
    };

    const clearTimers = () => {
      if (resyncTimer) clearTimeout(resyncTimer);
      if (activationTimer) clearTimeout(activationTimer);
      if (sustainedUseTimer) clearTimeout(sustainedUseTimer);
      resyncTimer = null;
      activationTimer = null;
      sustainedUseTimer = null;
    };

    const { data } = client.auth.onAuthStateChange((_event, session) => {
      clearTimers();
      const userId = session?.user?.id;
      if (!userId) return;

      // Outside the auth callback (supabase-js must not be awaited inside it)
      // and after first paint.
      resyncTimer = setTimeout(
        () => void resyncPushRegistration(client, userId),
        3000,
      );

      // A returning account older than the onboarding window is activated
      // immediately. A brand-new account is a no-op at the DB layer.
      activationTimer = setTimeout(
        () => void markReactivationActivated(),
        3000,
      );

      // Staying in WYNOS through onboarding also counts as real activation.
      sustainedUseTimer = setTimeout(
        () => void markReactivationActivated(),
        REACTIVATION_ACTIVE_AFTER_MS + REACTIVATION_TIMER_GRACE_MS,
      );
    });

    return () => {
      clearTimers();
      data.subscription.unsubscribe();
    };
  }, []);

  return null;
}
