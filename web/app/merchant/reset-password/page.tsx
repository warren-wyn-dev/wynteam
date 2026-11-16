import { redirect } from "next/navigation";

export const metadata = { title: "ตั้งรหัสผ่านใหม่ — WYNOS Merchant" };

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function MerchantResetPasswordPage({ searchParams }: { searchParams: SearchParams }) {
  // A recovery email link carries its one-time code in the query string; dropping it
  // would show "link invalid or expired" for a valid link.
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(await searchParams)) {
    for (const item of Array.isArray(value) ? value : value === undefined ? [] : [value]) params.append(key, item);
  }
  if (!params.has("returnTo")) params.set("returnTo", "/merchant/login");
  redirect(`/reset-password?${params.toString()}`);
}
