import { ClubDetailGoldenRoute } from "@/components/club-detail-golden";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ClubDetailGoldenRoute clubId={id} />;
}
