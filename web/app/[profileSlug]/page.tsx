import { notFound } from "next/navigation";
import { ProfileSlugResolver } from "@/components/profile-slug-resolver";

export default async function Page({ params }: { params: Promise<{ profileSlug: string }> }) {
  const { profileSlug } = await params;
  if (!profileSlug.startsWith("@") || profileSlug.length < 2) notFound();
  return <ProfileSlugResolver username={decodeURIComponent(profileSlug.slice(1))} />;
}
