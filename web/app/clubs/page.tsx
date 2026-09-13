"use client";

import { useSearchParams } from "next/navigation";
import { ClubsRoute } from "@/components/clubs-routes";

export default function Page() {
  const params = useSearchParams();
  return <ClubsRoute mine={params.get("mine") === "1"} />;
}
