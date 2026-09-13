"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, EmptyState, LoadingState } from "@/components/phase3-ui";

function Resolver({ client, userId, username }: { client: SupabaseClient; userId: string; username: string }) {
  const router = useRouter();
  const [missing, setMissing] = useState(false);
  useEffect(() => {
    let live = true;
    void client.from("profiles").select("id").eq("username", username).maybeSingle().then(({ data, error }) => {
      if (!live) return;
      if (error || !data) setMissing(true);
      else router.replace(`/profile/${data.id}`);
    });
    return () => { live = false; };
  }, [client, router, username]);
  return <AppChrome title={`@${username}`} userId={userId} backHref="/">{missing ? <EmptyState>ไม่พบโปรไฟล์</EmptyState> : <LoadingState />}</AppChrome>;
}

export function ProfileSlugResolver({ username }: { username: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <Resolver client={client} userId={userId} username={username} />}</DeveloperRouteGate>;
}
