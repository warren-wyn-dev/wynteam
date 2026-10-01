import { redirect } from "next/navigation";

export const metadata = { title: "ลืมรหัสผ่าน — WYNOS Merchant" };

export default function MerchantForgotPasswordPage() {
  redirect("/forgot-password");
}
