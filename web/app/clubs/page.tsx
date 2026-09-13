import { ClubsRoute } from "@/components/clubs-routes";

export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ mine?: string }>;
}) {
  const params = await searchParams;
  return <ClubsRoute mine={params.mine === "1"} />;
}
