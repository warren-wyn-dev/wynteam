import { QuoteDetailRoute } from "@/components/quote-detail-route";

export const metadata = { title: "WYNOS — โพสต์อ้างอิง" };

export default async function Page({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <QuoteDetailRoute quoteId={id} />;
}
