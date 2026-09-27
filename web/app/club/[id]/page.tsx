import type { Metadata } from "next";

import { ClubDetailGoldenRoute } from "@/components/club-detail-golden";
import { shareMetadata } from "@/lib/share-metadata";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  return shareMetadata("Club บน WYNOS", "เปิดดู Club นี้บน WYNOS", `/club/${id}`);
}

export default async function Page({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ tab?: string | string[] }>;
}) {
  const { id } = await params;
  // A Club announcement notification links to ?tab=announcements.
  const { tab } = await searchParams;
  return <ClubDetailGoldenRoute clubId={id} initialTab={tab === "announcements" ? "announcements" : undefined} />;
}
