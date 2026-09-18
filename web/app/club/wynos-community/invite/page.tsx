import { redirect } from "next/navigation";

import { InviteClubReferenceScreen } from "@/components/content-reference/club-screens";

// Reference fixture (mock data, no auth gate) for tests/browser/content-reference-flow.spec.ts
// under `next dev`. Production builds send real users to the real club detail route instead.
export default function Page() {
  if (process.env.NODE_ENV === "production") redirect("/club/wynos-community");
  return <InviteClubReferenceScreen />;
}
