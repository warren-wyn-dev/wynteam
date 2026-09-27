import { notFound } from "next/navigation";

import { ClubAnnouncementsFixture } from "@/components/dev/club-announcements-fixture";

// WYN-137 is Beta2 (developer-only): this preview exists only for next dev
// and Playwright, never as a production route.
export default function ClubAnnouncementsFixturePage() {
  if (process.env.NODE_ENV !== "development") notFound();
  return <ClubAnnouncementsFixture />;
}
