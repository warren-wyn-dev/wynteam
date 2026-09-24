"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { FoodDemoApp } from "@/components/food/food-demo-app";
import { AppChrome } from "@/components/phase3-ui";

type Access = "checking" | "allowed" | "denied";

function FoodDeveloperPreview({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const [access, setAccess] = useState<Access>("checking");

  useEffect(() => {
    let live = true;
    // Recheck at the destination. Home's developer-only shortcut is not
    // an authorization control. Deny by default on missing data or errors.
    void (async () => {
      try {
        const { data, error } = await client.rpc("is_developer_account");
        if (live) setAccess(!error && data === true ? "allowed" : "denied");
      } catch {
        if (live) setAccess("denied");
      }
    })();
    return () => { live = false; };
  }, [client, userId]);

  useEffect(() => {
    if (access === "denied") router.replace("/");
  }, [access, router]);

  if (access !== "allowed") {
    return <main className="route-state" aria-label="กำลังตรวจสอบสิทธิ์"><div className="route-system-spinner" /></main>;
  }

  return (
    <AppChrome title="" userId={userId} headerMode="hidden" showBottomNav={false}>
      <FoodDemoApp />
    </AppChrome>
  );
}

/** Only confirmed developer accounts reach the customer UI preview.
 * Nothing in this preview calls ordering, payment, driver, or merchant APIs. */
export function WynosFoodPreviewRoute() {
  return (
    <DeveloperRouteGate>
      {({ client, userId }) => <FoodDeveloperPreview key={userId} client={client} userId={userId} />}
    </DeveloperRouteGate>
  );
}
