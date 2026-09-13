import { ClubDetailRoute } from "@/components/club-detail-route";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ClubDetailRoute clubId={id} />;
}
