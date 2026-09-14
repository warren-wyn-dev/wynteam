import { ProfileFixture } from "@/components/profile/profile-fixture";

export default async function ProfileFixturePage({
  searchParams,
}: {
  searchParams: Promise<{ variant?: string }>;
}) {
  const { variant } = await searchParams;
  return <ProfileFixture variant={variant === "other" ? "other" : "own"} />;
}
