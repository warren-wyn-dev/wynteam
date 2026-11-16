import { redirect } from "next/navigation";

export const metadata = { title: "ลืมรหัสผ่าน — Zoky Merchant" };

export default function MerchantForgotPasswordPage() {
  // Keep the merchant on the Merchant sign-in once the new password is set.
  redirect("/forgot-password?returnTo=%2Fmerchant%2Flogin");
}
