import { ClubDetailGoldenRoute } from "@/components/club-detail-golden";
import { ClubDetailReferenceScreen } from "@/components/content-reference/club-screens";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (id === "wynos-community") return <ClubDetailReferenceScreen />;
  return <ClubDetailGoldenRoute clubId={id} />;
}
