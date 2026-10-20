import { ForgotPasswordScreen } from "@/components/auth-flow/screens";
import { passwordRecoveryReturnPath } from "@/lib/password-recovery-link";

type Props = { searchParams: Promise<{ returnTo?: string | string[] }> };

export async function generateMetadata({ searchParams }: Props) {
  const returnTo = passwordRecoveryReturnPath((await searchParams).returnTo);
  return { title: returnTo === "/food/login" ? "ลืมรหัสผ่าน — ZOKY" : "Wynos — ลืมรหัสผ่าน" };
}

export default async function ForgotPasswordPage({ searchParams }: Props) {
  const returnTo = passwordRecoveryReturnPath((await searchParams).returnTo);
  return <ForgotPasswordScreen returnTo={returnTo} />;
}
