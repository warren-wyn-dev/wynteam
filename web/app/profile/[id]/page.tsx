import { BookmarksRoute } from "@/components/bookmarks-route";
import { ProfileRoute } from "@/components/profile-route";

export default async function Page({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ tab?: string }>;
}) {
  const [{ id }, query] = await Promise.all([params, searchParams]);
  if (query.tab === "saved") return <BookmarksRoute />;
  return <ProfileRoute profileId={id} />;
}
