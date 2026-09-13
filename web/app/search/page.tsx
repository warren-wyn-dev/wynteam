"use client";

import { useSearchParams } from "next/navigation";

import { ClubsRoute, CreateClubRoute } from "@/components/clubs-routes";
import { SearchRoute } from "@/components/search-route";

export default function Page() {
  const params = useSearchParams();
  const club = params.get("club");
  if (club === "create") return <CreateClubRoute />;
  if (club === "mine") return <ClubsRoute mine />;
  return <SearchRoute />;
}
