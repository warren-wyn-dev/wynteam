import { SignupDraftProvider } from "@/components/auth-flow/signup-draft-context";

export default function AuthFlowLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <SignupDraftProvider>{children}</SignupDraftProvider>;
}
