import { ClubsRoute, CreateClubRoute } from "@/components/clubs-routes";
import { SearchRoute } from "@/components/search-route";

export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ club?: string }>;
}) {
  const params = await searchParams;
  if (params.club === "create") return <CreateClubRoute />;
  if (params.club === "mine") return <ClubsRoute mine />;
  return <SearchRoute />;
}
