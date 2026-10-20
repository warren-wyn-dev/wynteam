import { ResetPasswordScreen } from "@/components/auth-flow/screens";
import { passwordRecoveryReturnPath } from "@/lib/password-recovery-link";

type Props = { searchParams: Promise<{ returnTo?: string | string[] }> };

export async function generateMetadata({ searchParams }: Props) {
  const returnTo = passwordRecoveryReturnPath((await searchParams).returnTo);
  return { title: returnTo === "/food/login" ? "ตั้งรหัสผ่านใหม่ — ZOKY" : "Wynos — ตั้งรหัสผ่านใหม่" };
}

export default async function ResetPasswordPage({ searchParams }: Props) {
  const returnTo = passwordRecoveryReturnPath((await searchParams).returnTo);
  return <ResetPasswordScreen returnTo={returnTo} />;
}
