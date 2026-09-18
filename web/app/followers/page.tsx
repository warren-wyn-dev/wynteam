import { redirect } from "next/navigation";

import { FollowersReferenceScreen } from "@/components/content-reference/profile-screens";

export const metadata = { title: "Wynos — ผู้ติดตาม" };

// Reference fixture (mock data, no auth gate) for tests/browser/content-reference-flow.spec.ts
// under `next dev`. Production builds send real users to their real profile instead
// (the real followers/following lists live at /profile/[id]/followers and /following).
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string }>;
}) {
  const query = await searchParams;
  if (process.env.NODE_ENV === "production") redirect("/profile/me");
  const initialTab = query.tab === "following" ? "following" : "followers";
  return <FollowersReferenceScreen initialTab={initialTab} />;
}
