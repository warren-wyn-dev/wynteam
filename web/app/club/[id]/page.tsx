import type { Metadata } from "next";

import { ClubDetailGoldenRoute } from "@/components/club-detail-golden";
import { shareMetadata } from "@/lib/share-metadata";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  return shareMetadata("Club บน WYNOS", "เปิดดู Club นี้บน WYNOS", `/club/${id}`);
}

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ClubDetailGoldenRoute clubId={id} />;
}
