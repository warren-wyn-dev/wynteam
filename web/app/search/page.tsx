import { ClubsRoute, CreateClubRoute } from "@/components/clubs-routes";
import { SearchReferenceScreen } from "@/components/content-reference/screens";

export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ club?: string }>;
}) {
  const params = await searchParams;
  if (params.club === "create") return <CreateClubRoute />;
  if (params.club === "mine") return <ClubsRoute mine />;
  return <SearchReferenceScreen />;
}
