import { notFound } from "next/navigation";
import { ProfileSlugRoute } from "@/components/profile-route";

export default async function Page({ params }: { params: Promise<{ profileSlug: string }> }) {
  const { profileSlug } = await params;
  if (!profileSlug.startsWith("@") || profileSlug.length < 2) notFound();
  return <ProfileSlugRoute username={decodeURIComponent(profileSlug.slice(1))} />;
}
