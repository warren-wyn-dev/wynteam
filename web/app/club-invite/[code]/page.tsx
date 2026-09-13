import { ClubInviteLinkRoute } from "@/components/club-invite-route";

export default async function Page({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  return <ClubInviteLinkRoute code={code} />;
}
