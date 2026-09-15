import { FollowersReferenceScreen } from "@/components/content-reference/profile-screens";

export const metadata = { title: "Wynos — ผู้ติดตาม" };

export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string }>;
}) {
  const query = await searchParams;
  const initialTab = query.tab === "following" ? "following" : "followers";
  return <FollowersReferenceScreen initialTab={initialTab} />;
}
