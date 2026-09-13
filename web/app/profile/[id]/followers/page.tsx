import { ProfileFollowListRoute } from "@/components/profile-follow-list-route";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ProfileFollowListRoute profileId={id} kind="followers" />;
}
