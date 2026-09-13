"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { LoadingState } from "@/components/phase3-ui";

function Redirect({ userId }: { userId: string }) {
  const router = useRouter();
  useEffect(() => { router.replace(`/profile/${userId}`); }, [router, userId]);
  return <LoadingState />;
}

export function MeProfileRedirect() {
  return <DeveloperRouteGate>{({ userId }) => <Redirect userId={userId} />}</DeveloperRouteGate>;
}
