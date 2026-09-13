import { ClubInviteRoute } from "@/components/deep-link-routes";

export default async function Page({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  return <ClubInviteRoute code={code} />;
}
