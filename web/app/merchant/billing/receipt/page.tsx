import type { Metadata } from "next";

import { MerchantBillingReceipt } from "@/components/merchant/merchant-billing-receipt";

export const metadata: Metadata = {
  title: "ใบเสร็จค่าบริการ ZOKY",
  robots: { index: false, follow: false },
};

/** ZOKY-BILLING-001: printable receipt of a paid monthly fee (owner/admin). */
export default async function MerchantBillingReceiptPage({ searchParams }: { searchParams: Promise<{ invoice?: string | string[] }> }) {
  const { invoice } = await searchParams;
  return <MerchantBillingReceipt invoiceId={typeof invoice === "string" ? invoice : ""} />;
}
