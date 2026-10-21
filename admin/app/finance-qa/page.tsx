import { notFound } from "next/navigation";
import { FinanceQaGate } from "@/components/admin/finance-qa-gate";
export default function FinanceQaPage() {
  if (process.env.NEXT_PUBLIC_SUPABASE_URL !== "https://pcatuxtenluqzjzzwsvl.supabase.co") notFound();
  return <main className="mx-auto max-w-5xl space-y-6 p-4"><h1 className="text-xl font-semibold">ZOKY · การเงิน Sandbox</h1><FinanceQaGate /></main>;
}
