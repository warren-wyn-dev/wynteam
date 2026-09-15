import { CreateClubDraftProvider } from "@/components/content-reference/club-create-context";

export default function CreateClubLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <CreateClubDraftProvider>{children}</CreateClubDraftProvider>;
}
