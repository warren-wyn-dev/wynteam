import type { Metadata } from "next";

import { QuoteDetailRoute } from "@/components/quote-detail-route";
import { shareMetadata } from "@/lib/share-metadata";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  return shareMetadata("WYNOS — โพสต์อ้างอิง", "เปิดดูโพสต์อ้างอิงนี้บน WYNOS", `/quote/${id}`);
}

export default async function Page({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <QuoteDetailRoute quoteId={id} />;
}
