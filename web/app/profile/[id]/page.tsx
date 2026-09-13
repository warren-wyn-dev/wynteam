import { ProfileRoute } from "@/components/profile-route";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ProfileRoute profileId={id} />;
}
