import { redirect } from "next/navigation";

export const metadata = { title: "ตั้งรหัสผ่านใหม่ — WYNOS Merchant" };

export default function MerchantResetPasswordPage() {
  redirect("/reset-password");
}
